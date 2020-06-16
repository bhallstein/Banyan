#import "AppDelegate.h"
#import "Document.h"
#import "ScrollingTreeView.h"
#include "Banyan/GenericTree/Diatom/DiatomSerialization.h"
#include "Banyan/Banyan.h"
#include "NodeListView.h"
#include "NodeLoaderWinCtrlr.h"
#include "NodeDefFile.h"
#include <fstream>
#include <cassert>


@interface Document () {
  std::vector<Diatom> tree;
  std::map<void*, std::string> control_names;

  std::vector<Diatom> nodeDefs;
  std::vector<NodeDefFile> definition_files;

  BOOL should_initially_show_loader_window;
}

@property IBOutlet ScrollingTreeView *view__scrollingTree;
@property IBOutlet NSScrollView *view__nodeOptions;
@property IBOutlet NSScrollView *view__nodeListContainer;
@property NodeListView *view__nodeList;

@property IBOutlet NSTextField *label__nodeType;
@property IBOutlet NSTextField *label__nodeDescr;
@property IBOutlet NSTextField *label__optionsHeader;

@property NSArray *form_labels;
@property NSArray *form_controls;

@property (strong, nonatomic) NodeLoaderWinCtrlr *nodeLoaderWC;

@end


@implementation Document


-(instancetype)init {
  if (self = [super init]) {
    self.selectedNode = NotFound;
    _loaderWinOpen = NO;
    should_initially_show_loader_window = NO;
  }
  return self;
}

-(void)awakeFromNib {
  [self setNodeOptionsViewToEmpty];
}

-(void)windowControllerDidLoadNib:(NSWindowController *)aController {
  [super windowControllerDidLoadNib:aController];

  if (!self.view__nodeList) {
    self.view__nodeList = [[NodeListView alloc] initWithFrame:self.view__nodeListContainer.frame];
    [self.view__nodeListContainer setDocumentView:self.view__nodeList];
  }

  if (!self.nodeLoaderWC) {
    self.nodeLoaderWC = [[NodeLoaderWinCtrlr alloc] initWithDoc:self];
    [self setUpFileDropCallback];
    if (should_initially_show_loader_window) {
      [self setLoaderWinOpen:YES];
      should_initially_show_loader_window = NO;
    }
  }
}

+(BOOL)autosavesInPlace { return NO; }
-(NSString *)windowNibName { return @"Document"; }
-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }


// Save
// ------------------------------------

-(NSData*)dataOfType:(NSString*)typeName error:(NSError**)outError {
  if (tree.size() > 1) {
    NSString *msg = @"The document currently contains orphaned nodes. Please fix before saving.";
    *outError = [NSError errorWithDomain:@"" code:0
                                userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
    return nil;
  }

  Diatom save;

  // Save definition file locations, if present
  if (definition_files.size() > 0) {
    save["definitionFiles"] = Diatom();
    for (size_t i = 0; i < definition_files.size(); ++i) {
      std::string k = numeric_key_string("f", (int) i);
      save["definitionFiles"][k] = definition_files[i].path;
    }
  }

  // Return empty tree if no nodes
  if (tree.size() == 0) {
    Diatom save;
    save["treeDef"] = Diatom();
    save["treeDef"]["nodes"] = Diatom();
    save["treeDef"]["tree"] = GenericTree_Nodeless().toDiatom();
    std::string str = diatom__serialize(save);
    return [NSData dataWithBytes:str.c_str() length:str.size()];
  }

  // Build a GenericTree
  Diatom t = tree[0];
  std::vector<Diatom> nodes;
  GenericTree_Nodeless gt;

  // - assign node ids
  int node_id = 0;
  t.recurse([&](std::string name, Diatom &n) {
    if (is_node_diatom(&n)) {
      n["index"] = (double) node_id++;

      auto parent = find_node_parent(t, n["uid"].value__number);
      if (parent.uid != NotFound) {
        n["parent_index"] = get_node(t, parent.uid)["index"];
      }
      else {
        n["parent_index"] = (double) -1;
      }
    }
  }, true);

  // - convert to generictree
  t.recurse([&](std::string name, Diatom n) {
    if (is_node_diatom(&n)) {
      Diatom copy = n;
      copy.remove_child("minChildren");
      copy.remove_child("maxChildren");
      copy.remove_child("index");
      copy.remove_child("parent_index");
      copy.remove_child("children");
      copy.remove_child("uid");

      int i = (int) n["index"].value__number;
      int i__gt = gt.addNode(n["parent_index"].value__number);
      assert(i == i__gt);
      assert(i == nodes.size());

      nodes.push_back(copy);
    }
  }, true);

  // - serialize nodes
  save["treeDef"] = Diatom();
  save["treeDef"]["tree"] = gt.toDiatom();
  save["treeDef"]["nodes"] = Diatom();
  for (int i=0; i < nodes.size(); ++i) {
    std::string k = numeric_key_string("n", i);
    save["treeDef"]["nodes"][k] = nodes[i];
  }

  std::string str = diatom__serialize(save);
  return [NSData dataWithBytes:str.c_str() length:str.size()];
}


// Load
// ------------------------------------

-(BOOL)readFromData:(NSData*)data ofType:(NSString*)typeName error:(NSError**)outError {
  NSString *nsstr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (!nsstr) {
    NSString *msg = @"Couldn't convert the file to a string.";
    *outError = [NSError errorWithDomain:@"" code:0
                                userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
    return NO;
  }

  Diatom d = Diatom{Diatom::Type::Empty};
  std::vector<Diatom> nodes;
  std::vector<std::string> unknown_node_types;
  std::vector<std::string> unknown_node_properties;

  auto result = diatom__unserialize([nsstr UTF8String]);

  // Checks
  {
    // Check diatom loaded
    if (!result.success || result.d.is_empty()) {
      *outError = [NSError errorWithDomain:@"" code:0
                                  userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The file is not a valid .diatom file." }];
      return NO;
    }

    d = result.d;

    // Check has required parts
    if (!d["treeDef"].is_table()) {
      *outError = [NSError errorWithDomain:@"" code:0
                                  userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The file did not contain a \"treeDef\" object." }];
      return NO;
    }
    if (!d["treeDef"]["nodes"].is_table()) {
      *outError = [NSError errorWithDomain:@"" code:0
                                  userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The file did not contain a \"nodes\" object." }];
      return NO;
    }
    if (!d["treeDef"]["tree"].is_table()) {
      *outError = [NSError errorWithDomain:@"" code:0
                                  userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The file did not contain a \"valid tree\" object." }];
      return NO;
    }
  }


  // Load doc's node definitions
  {
    if (d["definitionFiles"].is_table()) {
      d["definitionFiles"].each([&](std::string &key, Diatom &d) {
        NSString *file = [NSString stringWithFormat:@"%s", d.value__string.c_str()];
        [self addNodeDef_FromFile:file];
      });
    }

    // If there were failures, open the node loader window
    for (auto &f : definition_files) {
      if (!f.succeeded) {
        putUpError(@"Node definitions not found",
                   @"The files might have been moved or deleted. Please re-import the missing definitions using the Node Loader window.");
        should_initially_show_loader_window = YES;
        break;
      }
    }
  }


  try {
    // Load the nodes vector
    d["treeDef"]["nodes"].each([&](std::string &key, Diatom &n) {
      const std::string &node_type = n["type"].value__string;

      double x = n["posX"].is_number() ? n["posX"].value__number : -1;
      double y = n["posY"].is_number() ? n["posY"].value__number : -1;

      Diatom node = [self mkNodeOfType:node_type atPos:NSPoint{x, y}];
      bool nodedef_found = node.index_of("minChildren") != node.descendants.end();

      // Add typed node
      if (nodedef_found) {
        n.each([&](std::string prop, Diatom value) {
          node[prop] = value;
        });
        nodes.push_back(node);
      }

      // Def not found: add dummy node
      else {
        node["type"] = "Unknown";
        node["original_type"] = node_type;

        nodes.push_back(node);
        unknown_node_types.push_back(node_type);
      }
    });

    // Load the tree
    GenericTree_Nodeless gt;
    gt.fromDiatom(d["treeDef"]["tree"]);

    // Populate diatom tree
    gt.walk([&](int i) {
      int i__parent = gt.parentIndex(i);

      Diatom node = nodes[i];
      UID uid__parent = i__parent == -1 ? NotFound : nodes[i__parent]["uid"].value__number;

      [self insert:node withParent:uid__parent withIndex:-1];
    });
  }
  catch (const std::runtime_error &exc) {
    NSString *msg = [NSString stringWithFormat:@"%s.", exc.what()];
    *outError = [NSError errorWithDomain:@"" code:0
                                userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
    return NO;
  }

  if (unknown_node_types.size() > 0) {
    putUpError(@"Warning: unknown node types detected",
               @"Load the missing node definition files in the Node Loader window.");
    should_initially_show_loader_window = YES;
  }

  if (unknown_node_properties.size() > 0) {
    for (auto &s : unknown_node_properties) {
      NSLog(@"Unknown node properties: %s", s.c_str());
    }
  }

  return YES;
}


// Node Loader window
// --------------------------------------

-(void)setSelectedNode:(UID)n {
  _selectedNode = n;
  if (n != NotFound) { [self setNodeOptionsViewToFilledOut]; }
  else               { [self setNodeOptionsViewToEmpty];     }
}

-(void)setLoaderWinOpen:(BOOL)loaderWinOpen {
  if (_loaderWinOpen == loaderWinOpen) {
    return;
  }

  _loaderWinOpen = loaderWinOpen;

  if (_loaderWinOpen) {
    [self.nodeLoaderWC showWindow:nil];
    [self.nodeLoaderWC.window makeKeyAndOrderFront:nil];
    [self addWindowController:self.nodeLoaderWC];
  }
  else {
    [self.nodeLoaderWC close];
    [self removeWindowController:self.nodeLoaderWC];
  }
}


// Tree manipulation
// --------------------------------------

-(void)detach:(UID)uid {
  // Removes & destroys -- caller may want to copy the Diatom beforehand

  UIDParentSearchResult result = find_node_parent(tree, uid);

  // If no parent, remove from top-level vector
  if (result.uid == NotFound) {
    auto it = std::find_if(tree.begin(), tree.end(), [&](Diatom d) {
      return d["uid"].value__number == uid;
    });
    if (it != tree.end()) {
      tree.erase(it);
    }
  }

  // If parent, remove from parent
  else {
    [self getNode:result.uid]["children"].remove_child(result.child_name);
    return;
  }
}

-(UID)createUID {
  static UID uid = 0;

  do {
    uid += 1;
  } while ([self getNode:uid].type == Diatom::Type::Table);

  return uid;
}

-(Diatom)mkNodeOfType:(std::string)type atPos:(NSPoint)p {
  Diatom node;

  for (auto &def : [self allNodeDefs]) {
    if (def["type"].value__string == type) {
      node = def;
    }
  }

  node["posX"] = p.x;
  node["posY"] = p.y;
  node["uid"] = [self createUID];

  return node;
}

-(void)insert:(Diatom)n withParent:(UID)uid__parent withIndex:(int)i {
  // Insert into top-level vector
  if (uid__parent == NotFound) {
    tree.insert(tree.end(), n);
    return;
  }

  // Insert under parent
  Diatom &parent = [self getNode:uid__parent];
  assert(is_node_diatom(&parent));

  if (parent["children"].is_empty()) {
    parent["children"] = Diatom{Diatom::Type::Table};
  }

  // Copy children into temporary vector
  std::vector<Diatom> children;
  std::transform(parent["children"].descendants.begin(),
                 parent["children"].descendants.end(),
                 std::back_inserter(children),
                 [](Diatom::DTableEntry entry) { return entry.item; });
  if (i == -1) {
    i = (int) children.size();
  }
  children.insert(children.begin() + i, n);

  // Set parent["children"]
  parent["children"] = Diatom();
  for (int i=0; i < children.size(); ++i) {
    parent["children"][numeric_key_string("n", i)] = children[i];
  }
}

UID node_at_point(Diatom tree, NSPoint p, float nw, float nh) {
  UID result = NotFound;

  tree.recurse([&](std::string k, Diatom &d) {
    if (is_node_diatom(&d)) {
      float x = d["posX"].value__number;
      float y = d["posY"].value__number;
      bool overlaps = (
        p.x >= x &&
        p.y >= y &&
        p.x < x + nw &&
        p.y < y + nh
      );
      if (overlaps) {
        result = d["uid"].value__number;
      }
    }
  }, true);

  return result;
}

-(UID)nodeAtPoint:(NSPoint)p nodeWidth:(float)nw nodeHeight:(float)nh {
  for (auto t : tree) {
    UID uid = node_at_point(t, p, nw, nh);
    if (uid != NotFound) {
      return uid;
    }
  }

  return NotFound;
}

-(std::vector<Diatom>&)getTree {
  return tree;
}

-(Diatom&)getNode:(UID)uid {
  for (auto &t : tree) {
    Diatom &result = get_node(t, uid);
    if (!result.is_empty()) {
      return result;
    }
  }

  return EmptyDiatom;
}


// Node options view
// --------------------------------------

-(void)setNodeOptionsViewToEmpty {
  self.label__nodeType.stringValue = @"";
  self.label__nodeDescr.stringValue = @"";
  self.label__optionsHeader.hidden = YES;

  for (id control in self.form_controls) {
    [control removeFromSuperview];
  }
  for (id label in self.form_labels) {
    [label removeFromSuperview];
  }
  self.form_labels = nil;
  self.form_controls = nil;

  control_names.clear();
}

-(void)setNodeOptionsViewToFilledOut {
  [self setNodeOptionsViewToEmpty];
  if (self.selectedNode == NotFound) {
    return;
  }

  Diatom d = [self getNode:self.selectedNode];
  auto n_type = d["type"].value__string;
  auto n_desc = self.appDelegate.descriptions[n_type];
  if (n_type == "Unknown") {
    n_desc = std::string("Warning: type '") + d["original_type"].value__string + std::string("' is not loaded");
  }

  self.label__nodeType.stringValue = nsstr(n_type);
  self.label__nodeDescr.stringValue = nsstr(n_desc);

  auto settables = node_settable_properties(d);
  if (settables.size() == 0) {
    return;
  }

  self.label__optionsHeader.hidden = NO;

  NSMutableArray *temp_controls = [[NSMutableArray alloc] init];
  NSMutableArray *temp_labels = [[NSMutableArray alloc] init];

  float view_width = self.view__nodeOptions.contentSize.width;
  float x_padding = 12.;
  float w_available = (view_width - 3 * x_padding);
  float w_label   = w_available * 0.75;
  float w_control = w_available * 0.25;
  float x_control = x_padding + w_label + x_padding;

  float checkbox_size = 18.;
  float x_checkbox = view_width - x_padding - checkbox_size;

  float vInc = 26.;
  float vOffset = 138.;
  NSRect checkbox_frame = { x_checkbox, 0, checkbox_size, checkbox_size };
  NSRect label__frame   = { 0, 0, w_label, 17 };
  NSRect control_frame  = { 0, 0, w_control, 19 };

  int ind = 0;
  for (auto &property_name : settables) {
    Diatom prop = d[property_name];

    float v = vOffset + ind * vInc;

    // Create label
    label__frame.origin = { x_padding, v };
    NSTextField *label = [[NSTextField alloc] initWithFrame:label__frame];
    label.stringValue = nsstr(property_name);
    label.font = [NSFont systemFontOfSize:13.];
    label.textColor = [NSColor colorWithCalibratedRed:0.27 green:0.27 blue:0.26 alpha:1.0];
    [label setBezeled:NO];
    [temp_labels addObject:label];
    [self.view__nodeOptions addSubview:label];

    if (prop.is_bool()) {
      // Create checkbox
      checkbox_frame.origin.y = v - 1;
      NSButton *checkbox = [[NSButton alloc] initWithFrame:checkbox_frame];
      checkbox.target = self;
      checkbox.action = @selector(formButtonClicked:);
      if (prop.value__bool) {
        checkbox.state = NSOnState;
      }
      [checkbox setButtonType:NSSwitchButton];
      [temp_controls addObject:checkbox];
      [self.view__nodeOptions addSubview:checkbox];

      void* checkbox_ptr = (__bridge void*) checkbox;
      control_names[checkbox_ptr] = property_name;
    }

    else if (prop.is_string() || prop.is_number()) {
      // Create string input
      control_frame.origin = { x_control, v - 1 };
      NSTextField *control = [[NSTextField alloc] initWithFrame:control_frame];
      control.font = [NSFont systemFontOfSize:13.];
      control.delegate = self;
      if (prop.is_string()) {
        control.stringValue = nsstr(prop.value__string);
      }
      else {
        control.doubleValue = prop.value__number;
      }
      [temp_controls addObject:control];
      [self.view__nodeOptions addSubview:control];

      void* ctrl_pointer = (__bridge void*) control;
      control_names[ctrl_pointer] = property_name;
    }

    else {
      // Consider displaying an error message
    }

    ++ind;
  }

  self.form_controls = [NSArray arrayWithArray:temp_controls];
  self.form_labels = [NSArray arrayWithArray:temp_labels];
}


// Node options callbacks
// --------------------------------------

-(void)controlTextDidChange:(NSNotification *)notif {
  void* p = (__bridge void*) notif.object;
  std::string property_name = control_names[p];

  Diatom &n = [self getNode:self.selectedNode];
  Diatom &prop = n[property_name];

  if (prop.is_string()) {
    prop.value__string = [[notif.object stringValue] UTF8String];
  }
  else if (prop.is_number()) {
    prop.value__number = [[notif.object stringValue] doubleValue];
  }
  else {
    putUpError(@"Incorrect property type",
               @"The expected property of the selected node did not have the expected type. This is unexpected and serious.");
  }
}

-(void)formButtonClicked:(NSButton*)button {
  void* p = (__bridge void*) button;
  std::string property_name = control_names[p];

  Diatom &n = [self getNode:self.selectedNode];
  Diatom &prop = n[property_name];

  if (prop.is_bool()) {
    prop.value__bool = button.state;
  }
  else {
    putUpError(@"Incorrect property type",
               @"The expected property of the selected node was not a boolean. This is unexpected and serious.");
  }
}


// Node definitions
// ------------------------------------

-(std::vector<Diatom>)documentNodeDefs {
  return nodeDefs;
}

-(std::vector<Diatom>)allNodeDefs {
  std::vector<Diatom> all = nodeDefs;
  std::vector<Diatom> builtins = self.appDelegate.builtinNodeDefs;
  all.insert(all.end(), builtins.begin(), builtins.end());

  return all;
}

-(void*)getDefinitionFiles {
  return &definition_files;
}

-(void)addNodeDef:(Diatom)def {
  nodeDefs.push_back(def);

  if (def["description"].is_string()) {
    [self.appDelegate descriptions][def["type"].value__string] = def["description"].value__string;
  }
}

std::string read_file(std::string filename) {
  std::ifstream file_stream(filename);
  return std::string(
    (std::istreambuf_iterator<char>(file_stream)),
    std::istreambuf_iterator<char>()
  );
}

-(BOOL)addNodeDef_FromFile:(NSString*)path {
  std::string path_str([path UTF8String]);

  auto s = read_file(path_str);
  auto result = diatom__unserialize(s);
  auto &d = result.d;

  if (!result.success) {
    definition_files.push_back({ false, path_str, result.error_string });
    return NO;
  }

  if (!d.is_table()) {
    definition_files.push_back({ false, path_str, "file does not contain a table" });
    return NO;
  }

  if (!(d["nodeDef"].is_table() && d["nodeDef"]["type"].is_string())) {
    definition_files.push_back({ true, path_str, "file does not have a 'nodeDef' table with a 'type' property" });
    return NO;
  }

  definition_files.push_back({ true, path_str });
  [self addNodeDef:d["nodeDef"]];

  return YES;
}

-(void)setUpFileDropCallback {
  // Load dropped nodes as Diatoms
  __unsafe_unretained typeof(self) weakSelf = self;
  [self.nodeLoaderWC setCB:^(NSArray *files) {
    // - Load each file into a Diatom object
    //    - If any fail, add to errors
    // - Ensure each has the required properties:
    //    - type
    //    - any options w/ defaults

    [weakSelf.nodeLoaderWC disp];

    NSMutableArray *failed = [NSMutableArray array];

    for (NSString *file in files) {
      BOOL result = [weakSelf addNodeDef_FromFile:file];
      if (!result) {
        [failed addObject:file];
      }
    }

    [weakSelf.view__nodeList setNeedsDisplay:YES];

    if ([failed count] != 0) {
      NSMutableString *errFilesList = [[NSMutableString alloc] init];
      for (int i=0; i < failed.count; ++i) {
        [errFilesList appendFormat:@"\n %@", failed[i]];
      }
      NSString *errStr = [NSString stringWithFormat:@"%@ %@",
                          @"The following definition files were invalid:", errFilesList];
      putUpError(@"Error loading node definitions", errStr);
      return;
    }
  }];
}

@end

