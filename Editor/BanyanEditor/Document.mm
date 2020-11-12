#import "AppDelegate.h"
#import "Document.h"
#import "BanyanView.h"
#include "NodeListView.h"
#include "DiatomSerialization.h"
#define _GT_ENABLE_SERIALIZATION
#include "GenericTree_Nodeless.h"

#include <fstream>
#include <cassert>

Diatom EmptyDiatom{Diatom::Type::Empty};


float initial_panel_width = 240.;
float vspace = 12;
float vspace_large = 32;


@interface Document () {
  std::vector<Diatom> tree;
  std::vector<Diatom> nodeDefs;
  std::map<void*, std::string> node_property_map;
  std::map<void*, std::string> node_state_context_map;
}

@property IBOutlet NSSplitView *view__splitContainer;
@property NSScrollView *view__nodeListContainer;
@property NodeListView *view__nodeList;
@property BanyanView *view__banyanLayout;
@property NSView *view__nodeOptions;

@property NSTextField *label__nodeType;
@property NSTextField *label__nodeDescr;
@property NSTextField *label__optionsHeader;
@property NSTextField *label__stateContextsHeader;
@property NSButton *button__addStateContext;
@property NSLayoutConstraint *label__stateContextsHeader__topConstraint;
@property NSLayoutConstraint *button__addStateContext__topConstraint;

@property NSArray *form_elements;
@property NSArray *state_context_elements;

@end


@implementation Document


-(instancetype)init {
  if (self = [super init]) {
    self.selectedNode = NotFound;
  }
  return self;
}

void set_up_subview(NSView *view, NSView *subview, float l_offset, float r_offset) {
  subview.translatesAutoresizingMaskIntoConstraints = NO;
  [subview setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
  [view addSubview:subview];

  if (l_offset != -1.) {
    [[subview.leftAnchor constraintEqualToAnchor:view.leftAnchor constant:l_offset] setActive:YES];
  }
  if (r_offset != -1.) {
    [[subview.rightAnchor constraintEqualToAnchor:view.rightAnchor constant:-r_offset] setActive:YES];
  }
}

NSTextField* mk_label(NSTextField *label, NSView *parent, float l_offset, float r_offset) {
  label.editable = NO;
  label.selectable = NO;
  label.bezeled = NO;
  set_up_subview(parent, label, l_offset, r_offset);

  return label;
}


-(void)awakeFromNib {
  self.selectedNode = NotFound;

  [self.view__splitContainer setArrangesAllSubviews:YES];

  self.view__nodeListContainer = [[NSScrollView alloc] init];
  self.view__banyanLayout      = [[BanyanView alloc] initWithFrame:{0,0,10,10}];
  self.view__nodeOptions       = [[NSView alloc] initWithFrame:{0,0,10,10}];

  // Add views to split view
  self.view__splitContainer.dividerStyle = NSSplitViewDividerStyleThin;
  [self.view__splitContainer addArrangedSubview:self.view__nodeListContainer];
  [self.view__splitContainer addArrangedSubview:self.view__banyanLayout];
  [self.view__splitContainer addArrangedSubview:self.view__nodeOptions];

  [self.view__splitContainer setHoldingPriority:2 forSubviewAtIndex:0];
  [self.view__splitContainer setHoldingPriority:1 forSubviewAtIndex:1];
  [self.view__splitContainer setHoldingPriority:3 forSubviewAtIndex:2];
  [self.view__splitContainer setPosition:initial_panel_width ofDividerAtIndex:0];
  [self.view__splitContainer setPosition:(self.view__splitContainer.frame.size.width - initial_panel_width) ofDividerAtIndex:1];

  // Set up Node List scroll view
  self.view__nodeListContainer.hasVerticalScroller = YES;
  [self.view__nodeListContainer setDocumentView:self.view__nodeList];
  self.view__nodeList = [[NodeListView alloc] initWithFrame:{{0,0}, self.view__nodeListContainer.contentSize}];
  [self.view__nodeListContainer setDocumentView:self.view__nodeList];
  self.view__nodeList.translatesAutoresizingMaskIntoConstraints = false;
  [[self.view__nodeList.topAnchor   constraintEqualToAnchor:self.view__nodeListContainer.contentView.topAnchor]   setActive:YES];
  [[self.view__nodeList.leftAnchor  constraintEqualToAnchor:self.view__nodeListContainer.contentView.leftAnchor]  setActive:YES];
  [[self.view__nodeList.rightAnchor constraintEqualToAnchor:self.view__nodeListContainer.contentView.rightAnchor] setActive:YES];

  // Set up Node Options view
  self.view__nodeOptions.translatesAutoresizingMaskIntoConstraints = false;
  [[self.view__nodeOptions.topAnchor    constraintEqualToAnchor:self.view__nodeOptions.topAnchor]    setActive:YES];
  [[self.view__nodeOptions.leftAnchor   constraintEqualToAnchor:self.view__nodeOptions.leftAnchor]   setActive:YES];
  [[self.view__nodeOptions.rightAnchor  constraintEqualToAnchor:self.view__nodeOptions.rightAnchor]  setActive:YES];
  [[self.view__nodeOptions.bottomAnchor constraintEqualToAnchor:self.view__nodeOptions.bottomAnchor] setActive:YES];

  self.label__nodeType      = mk_label([NSTextField textFieldWithString:@"Node type"],            self.view__nodeOptions, 12, 12);
  self.label__nodeType.hidden = YES;
  self.label__nodeDescr     = mk_label([NSTextField wrappingLabelWithString:@"Node description"], self.view__nodeOptions, 14, 14);
  self.label__optionsHeader = mk_label([NSTextField textFieldWithString:@"Properties"],           self.view__nodeOptions, 12, 12);
  self.label__stateContextsHeader = mk_label([NSTextField textFieldWithString:@"State contexts"],       self.view__nodeOptions, 12, 12);
  self.button__addStateContext = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameAddTemplate] target:self action:@selector(btn__addStateContext:)];
  self.button__addStateContext.bezelStyle = NSBezelStyleRoundRect;
  set_up_subview(self.view__nodeOptions, self.button__addStateContext, 12, -1);

  [[self.label__nodeType.topAnchor      constraintEqualToAnchor:self.view__nodeOptions.topAnchor   constant:18] setActive:YES];
  [[self.label__nodeDescr.topAnchor     constraintEqualToAnchor:self.label__nodeType.bottomAnchor  constant:9]  setActive:YES];
  [[self.label__optionsHeader.topAnchor constraintEqualToAnchor:self.label__nodeDescr.bottomAnchor constant:vspace_large] setActive:YES];

  self.label__nodeType.font      = [NSFont boldSystemFontOfSize:16];
  self.label__nodeDescr.font     = [NSFont systemFontOfSize:13];
  self.label__optionsHeader.font = [NSFont boldSystemFontOfSize:14];
  self.label__stateContextsHeader.font = [NSFont boldSystemFontOfSize:14];

  self.label__nodeType.textColor      = [NSColor labelColor];
  self.label__nodeDescr.textColor     = [NSColor systemGrayColor];
  self.label__optionsHeader.textColor = [NSColor labelColor];
  self.label__stateContextsHeader.textColor = [NSColor labelColor];

  [self setNodeOptionsViewToEmpty];
}

-(void)windowControllerDidLoadNib:(NSWindowController*)aController {
  [super windowControllerDidLoadNib:aController];
  [self setUpDefinitionDropCallback];
}

+(BOOL)autosavesInPlace { return NO; }
-(NSString *)windowNibName { return @"Document"; }
-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }


// Save
// ------------------------------------

-(NSData*)dataOfType:(NSString*)typeName error:(NSError**)outError {
  if (tree.size() > 1) {
    NSString *msg = @"The document contains orphaned nodes. Resolve this before saving.";
    *outError = [NSError errorWithDomain:@"" code:0
                                userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
    return nil;
  }
  if ([self containsUnknownNodes]) {
    NSString *msg =  @"The document contains nodes with definitions that failed to load. Resolve this before saving.";
    *outError = [NSError errorWithDomain:@"" code:0
                                userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
    return nil;
  }

  Diatom save;

  // Save any doc-level node definition
  if (nodeDefs.size() > 0) {
    save["nodeDefs"] = Diatom();
    for (auto def : nodeDefs) {
      int i = (int) save["nodeDefs"].table_entries.size();
      save["nodeDefs"][numeric_key_string("f", i)] = def;
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

  // Tweak positions so left-most and top-most +40
  float leftmost = 1000000.;
  float topmost  = 1000000.;
  tree[0].recurse([&](std::string k, Diatom &n) {
    if (is_node_diatom(&n)) {
      if (n["posX"].number_value < leftmost) { leftmost = n["posX"].number_value; }
      if (n["posY"].number_value < topmost)  { topmost  = n["posY"].number_value; }
    }
  }, true);
  float x_diff = leftmost - 40.;
  float y_diff = topmost - 40.;
  tree[0].recurse([=](std::string k, Diatom &n) {
    if (is_node_diatom(&n)) {
      n["posX"].number_value -= x_diff;
      n["posY"].number_value -= y_diff;
    }
  }, true);
  [self.view__banyanLayout adjustScrollX:x_diff Y:y_diff];

  // Build a GenericTree
  Diatom t = tree[0];
  std::vector<Diatom> nodes;
  GenericTree_Nodeless gt;

  // - assign node ids
  int node_id = 0;
  t.recurse([&](std::string name, Diatom &n) {
    if (is_node_diatom(&n)) {
      n["index"] = (double) node_id++;

      auto parent = find_node_parent(t, n["uid"].number_value);
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

      int i = (int) n["index"].number_value;
      int i__gt = gt.addNode(n["parent_index"].number_value);
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
  if (d["nodeDefs"].is_table()) {
    d["nodeDefs"].each([&](std::string &key, Diatom &d) {
      [self addNodeDef:d];
    });
  }

  try {
    // Load the nodes vector
    d["treeDef"]["nodes"].each([&](std::string &key, Diatom &n) {
      const std::string &node_type = n["type"].string_value;

      double x = n["posX"].is_number() ? n["posX"].number_value : -1;
      double y = n["posY"].is_number() ? n["posY"].number_value : -1;

      Diatom node = [self mkNodeOfType:node_type atPos:NSPoint{x, y}];
      bool nodedef_found = node.index_of("minChildren") != node.table_entries.end();

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
      UID uid__parent = i__parent == -1 ? NotFound : nodes[i__parent]["uid"].number_value;

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
               @"Please load the missing node definitions by dragging them onto the node list on the left.");
  }

  if (unknown_node_properties.size() > 0) {
    for (auto &s : unknown_node_properties) {
      NSLog(@"Unknown node properties: %s", s.c_str());
    }
  }

  return YES;
}


// Tree manipulation
// --------------------------------------

-(void)detach:(UID)uid {
  // Removes & destroys -- caller may want to copy the Diatom beforehand
  UIDParentSearchResult result = find_node_parent(tree, uid);

  // If no parent, remove from top-level vector
  if (result.uid == NotFound) {
    auto it = std::find_if(tree.begin(), tree.end(), [=](Diatom d) {
      return d["uid"].number_value == uid;
    });
    if (it != tree.end()) {
      tree.erase(it);
    }
  }

  // If parent, remove from parent
  else {
    Diatom &parent = [self getNode:result.uid];
    parent["children"].remove_child(result.child_name);
    regularise_node_keys(parent["children"]);
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
    if (def["type"].string_value == type) {
      node = def;
    }
  }

  node["posX"] = p.x;
  node["posY"] = p.y;
  node["uid"] = [self createUID];

  return node;
}

-(void)insert:(Diatom)n withParent:(UID)uid__parent withIndex:(int)i {
  // Insert as orphan in top-level vector
  if (uid__parent == NotFound) {
    tree.push_back(n);
    return;
  }

  // Insert as child
  Diatom &parent = [self getNode:uid__parent];
  assert(is_node_diatom(&parent));

  if (parent["children"].is_empty()) {
    parent["children"] = Diatom{Diatom::Type::Table};
  }

  Diatom &children = parent["children"];
  if (i == -1) {
    i = (int) children.table_entries.size();
  }
  children.table_entries.insert(children.table_entries.begin() + i, { "TempKey", n });
  regularise_node_keys(children);
}

UID node_at_point(Diatom tree, NSPoint p, float nw, float nh) {
  UID result = NotFound;

  tree.recurse([&](std::string k, Diatom &d) {
    if (is_node_diatom(&d)) {
      float x = d["posX"].number_value;
      float y = d["posY"].number_value;
      bool overlaps = (
        p.x >= x &&
        p.y >= y &&
        p.x < x + nw &&
        p.y < y + nh
      );
      if (overlaps) {
        result = d["uid"].number_value;
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

-(bool)containsUnknownNodes {
  bool unknown_nodes = false;

  for (auto &t : tree) {
    t.recurse([&](std::string name, Diatom &n) {
      if (is_node_diatom(&n)) {
        if (n["type"].string_value == "Unknown") {
          unknown_nodes = true;
        }
      }
    });
  }

  return unknown_nodes;
}


// Node options view
// --------------------------------------

-(void)setSelectedNode:(UID)n {
  _selectedNode = n;
  if (n != NotFound) { [self setNodeOptionsViewToFilledOut]; }
  else               { [self setNodeOptionsViewToEmpty];     }
}

-(void)setNodeOptionsViewToEmpty {
  self.label__nodeType.hidden = YES;
  self.label__nodeType.stringValue = @"";
  self.label__nodeDescr.stringValue = @"";
  self.label__optionsHeader.hidden = YES;
  self.label__stateContextsHeader.hidden = YES;
  self.button__addStateContext.hidden = YES;

  self.label__stateContextsHeader__topConstraint.active = NO;
  self.button__addStateContext__topConstraint.active = NO;
  [self.label__stateContextsHeader removeConstraint:self.label__stateContextsHeader__topConstraint];
  [self.button__addStateContext removeConstraint:self.button__addStateContext__topConstraint];

  for (id control in self.form_elements)          { [control removeFromSuperview]; }
  for (id control in self.state_context_elements) { [control removeFromSuperview]; }
  self.form_elements = nil;
  self.state_context_elements = nil;

  node_property_map.clear();
  node_state_context_map.clear();
}

-(void)setNodeOptionsViewToFilledOut {
  [self setNodeOptionsViewToEmpty];
  if (self.selectedNode == NotFound) {
    return;
  }

  BOOL is_dark_mode = dark_mode(self.view__nodeOptions);
  Diatom d = [self getNode:self.selectedNode];

  auto node_type = d["type"].string_value;
  auto node_desc = self.appDelegate.descriptions[node_type];
  if (node_type == "Unknown") {
    node_desc = std::string("Warning: type '") + d["original_type"].string_value + std::string("' is not loaded");
  }

  NSColor *bg_color = view_background_color(is_dark_mode);
  [self.view__nodeOptions setWantsLayer:YES];
  self.view__nodeOptions.layer.backgroundColor    = bg_color.CGColor;
  self.label__nodeType.backgroundColor            = bg_color;
  self.label__optionsHeader.backgroundColor       = bg_color;
  self.label__stateContextsHeader.backgroundColor = bg_color;

  self.label__nodeType.hidden = NO;
  self.label__nodeType.stringValue = nsstr(node_type);
  self.label__nodeDescr.stringValue = nsstr(node_desc);

  // Settables
  auto settables = node_settable_properties(d);
  if (settables.size() > 0) {
    self.label__optionsHeader.hidden = NO;
    NSMutableArray *temp_elements = [[NSMutableArray alloc] init];

    for (auto &property_name : settables) {
      Diatom prop = d[property_name];
      NSTextField *prev = temp_elements.count > 0 ? temp_elements.lastObject : self.label__optionsHeader;

      // Create label
      NSTextField *label = [NSTextField textFieldWithString:nsstr(property_name)];
      mk_label(label, self.view__nodeOptions, 12, -1);
      label.textColor = [NSColor systemGrayColor];
      label.backgroundColor = bg_color;
      [[label.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:vspace] setActive:YES];
      [temp_elements addObject:label];

      // Create text input
      if (prop.is_string() || prop.is_number()) {
        NSTextField *text_field = [NSTextField textFieldWithString:@""];
        mk_label(text_field, self.view__nodeOptions, -1, 12);
        text_field.delegate = self;
        text_field.editable = YES;
        text_field.bezeled = YES;
        text_field.bezelStyle = NSTextFieldRoundedBezel;
        text_field.textColor = NSColor.blackColor;
        text_field.drawsBackground = YES;
        text_field.backgroundColor = NSColor.whiteColor;
        [[text_field.topAnchor constraintEqualToAnchor:label.topAnchor constant:-2] setActive:YES];
        [[text_field.leftAnchor constraintGreaterThanOrEqualToAnchor:label.rightAnchor constant:16] setActive:YES];
        if (prop.is_string()) {
          text_field.stringValue = nsstr(prop.string_value);
        }
        else {
          text_field.stringValue = nsstr(_DiatomSerialization::float_format(prop.number_value));
        }

        node_property_map[(__bridge void*)text_field] = property_name;
        [temp_elements addObject:text_field];
      }

      else if (prop.is_bool()) {
        NSButton *checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(btn__formElement:)];
        if (prop.bool_value) {
          checkbox.state = NSOnState;
        }
        set_up_subview(self.view__nodeOptions, checkbox, -1, 12);
        [[checkbox.topAnchor constraintEqualToAnchor:label.topAnchor constant:0] setActive:YES];

        node_property_map[(__bridge void*) checkbox] = property_name;
        [temp_elements addObject:checkbox];
      }
    }

    self.form_elements = [NSArray arrayWithArray:temp_elements];
  }

  // State contexts
  BOOL have_form_elements = self.form_elements.count > 0;
  BOOL have_options_header = !self.label__optionsHeader.hidden;
  NSTextField *v_prev = have_form_elements ? self.form_elements.lastObject :
    (have_options_header ? self.label__optionsHeader : self.label__nodeDescr);

  self.label__stateContextsHeader__topConstraint = [self.label__stateContextsHeader.topAnchor constraintEqualToAnchor:v_prev.bottomAnchor
                                                                                                             constant:vspace_large];
  self.label__stateContextsHeader__topConstraint.active = YES;
  self.label__stateContextsHeader.hidden = NO;

  NSMutableArray *temp_sc_elements = [[NSMutableArray alloc] init];
  d["state_contexts"].each([&](std::string k, Diatom sc) {
    assert(sc.is_string());
    std::string context_name = sc.string_value;
    NSTextField *prev = temp_sc_elements.count > 0 ? temp_sc_elements.lastObject : self.label__stateContextsHeader;

    // Create label
    NSTextField *label = [NSTextField textFieldWithString:nsstr(context_name)];
    mk_label(label, self.view__nodeOptions, 12, 40);
    label.editable = YES;
    label.delegate = self;
    label.focusRingType = NSFocusRingTypeNone;
    label.textColor = [NSColor systemGrayColor];
    label.backgroundColor = bg_color;
    [[label.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant: vspace] setActive:YES];
    [temp_sc_elements addObject:label];
    node_state_context_map[(__bridge void*) label] = k;

    // Create delete button
    NSButton *delete_btn = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate]
                                              target:self
                                              action:@selector(btn__deleteStateContext:)];
    set_up_subview(self.view__nodeOptions, delete_btn, -1, 12);
    [[delete_btn.topAnchor constraintEqualToAnchor:label.topAnchor constant: 0] setActive:YES];
    delete_btn.bezelStyle = NSBezelStyleRoundRect;
    node_state_context_map[(__bridge void*) delete_btn] = k;
    [temp_sc_elements addObject:delete_btn];
  });
  self.state_context_elements = [NSArray arrayWithArray:temp_sc_elements];

  // State context add btn
  self.button__addStateContext.hidden = NO;
  NSTextField *vprev__addbtn = self.state_context_elements.count > 0 ? self.state_context_elements.lastObject : self.label__stateContextsHeader;
  self.button__addStateContext__topConstraint = [self.button__addStateContext.topAnchor constraintEqualToAnchor:vprev__addbtn.bottomAnchor
                                                                                                       constant:vspace];
  self.button__addStateContext__topConstraint.active = YES;
}


// Node options callbacks
// --------------------------------------

-(void)controlTextDidChange:(NSNotification *)notif {
  if (self.selectedNode == NotFound) {
    return;
  }

  void* p = (__bridge void*) notif.object;

  auto it__node_prop = node_property_map.find(p);
  auto it__sc = node_state_context_map.find(p);

  if (it__node_prop != node_property_map.end()) {
    [self updateNodeProperty:notif.object];
  }
  else if (it__sc != node_state_context_map.end()) {
    [self updateNodeStateContext:notif.object];
  }
}

-(void)updateNodeProperty:(NSTextField*)control {
  std::string property_name = node_property_map[(__bridge void*) control];
  NSString *value = [control stringValue];

  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^-?[0-9]+(.{1}[0-9]+)?$"
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:&error];
  size_t float_matches = [regex numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)];

  Diatom &n = [self getNode:self.selectedNode];
  bool is_numeric = float_matches > 0;

  if (is_numeric) {
    double double_value;
    [[NSScanner scannerWithString:value] scanDouble:&double_value];
    n[property_name] = double_value;
  }
  else {
    n[property_name] = stdstring(value);
  }
}

-(void)updateNodeStateContext:(NSTextField*)control {
  NSString *value = [control stringValue];
  Diatom &n = [self getNode:self.selectedNode];
  std::string sc_key = node_state_context_map[(__bridge void*) control];

  n["state_contexts"][sc_key] = stdstring(value);
}

-(void)btn__formElement:(NSButton*)button {
  void* p = (__bridge void*) button;
  std::string property_name = node_property_map[p];

  Diatom &n = [self getNode:self.selectedNode];
  n[property_name] = (bool) button.state;
}

-(void)btn__addStateContext:(NSButton*)add_btn {
  if (self.selectedNode == NotFound) {
    return;
  }

  Diatom &d = [self getNode:self.selectedNode];
  if (!d.has("state_contexts")) {
    d["state_contexts"] = Diatom();
  }
  d["state_contexts"]["temp_key"] = std::string("MyStateContext");
  regularise_node_keys(d["state_contexts"]);

  [self setSelectedNode:self.selectedNode];
  [self.view__banyanLayout setNeedsDisplay:YES];
}

-(void)btn__deleteStateContext:(NSButton*)delete_btn {
  if (self.selectedNode == NotFound) {
    return;
  }

  std::string sc_key = node_state_context_map[(__bridge void*) delete_btn];
  Diatom &d = [self getNode:self.selectedNode];

  d["state_contexts"].remove_child(sc_key);
  regularise_node_keys(d["state_contexts"]);

  [self setSelectedNode:self.selectedNode];
  [self.view__banyanLayout setNeedsDisplay:YES];
}


// Node definitions
// ------------------------------------

-(std::vector<Diatom>)allNodeDefs {
  std::vector<Diatom> all = nodeDefs;
  std::vector<Diatom> builtins = self.appDelegate.nodeDefs;
  all.insert(all.end(), builtins.begin(), builtins.end());

  return all;
}

-(void)addNodeDef:(Diatom)def {
  auto i = std::find_if(nodeDefs.begin(), nodeDefs.end(), [&](Diatom d) {
    return d["type"].string_value == def["type"].string_value;
  });
  if (i != nodeDefs.end()) {
    nodeDefs.erase(i);
  }

  nodeDefs.push_back(def);

  if (def["description"].is_string()) {
    [self.appDelegate descriptions][def["type"].string_value] = def["description"].string_value;
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
    putUpError(nsstr(path_str), nsstr(result.error_string));
    return NO;
  }

  bool valid_structure = d.is_table() && d["nodeDef"].is_table() && d["nodeDef"]["type"].is_string();
  if (!valid_structure) {
    putUpError(nsstr(path_str),
               @"File must have a 'nodeDef' table with a 'type' property and optional 'description' property.");
    return NO;
  }

  [self addNodeDef:d["nodeDef"]];
  return YES;
}

-(void)setUpDefinitionDropCallback {
  __unsafe_unretained typeof(self) weak_self = self;

  self.view__nodeList.definitionDropCallback = ^(NSArray *files) {
    NSMutableArray *failed = [NSMutableArray array];

    for (NSString *file in files) {
      BOOL result = [weak_self addNodeDef_FromFile:file];
      if (!result) {
        [failed addObject:file];
      }
    }

    [weak_self.view__nodeList setNeedsDisplay:YES];

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
  };
}


// Zoom
// ------------------------------------

-(void)zoomIn {
  [self.view__banyanLayout zoomIn];
}

-(void)zoomOut {
  [self.view__banyanLayout zoomOut];
}

@end

