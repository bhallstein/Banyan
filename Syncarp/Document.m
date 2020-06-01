//
//  Document.m
//  Thingumy
//
//  Created by Ben on 19/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "AppDelegate.h"
#import "Document.h"
#import "ScrollingTreeView.h"
#import "Helpers.h"
#include "Banyan/GenericTree/Diatom/DiatomSerialization.h"
#include "Banyan/Banyan.h"
#include "Wrapper.h"
#include "BuiltInNodeListView.h"
#include "NodeLoaderWinCtrlr.h"
#include "NodeDefFile.h"
#include <map>
#include <fstream>

/*
   ✓ Create wrapper struct for Diatom, with vector of children
   ✓ Hold a vector of these
   ✓ Add a node A as child of B:
       - remove it from all others’ children vectors
       - add it to B's children
   ✓ Add node:
       - just add it to the nodes vector, with no children
   ✓ Detach node:
       - remove it from all others’ children vectors
   ✓ Delete node:
       - detach it
       - clear its children vector & mark it as deleted
   ✓ Find a node from a position:
       - perform a coordinate system transform, from zoom & pan
	   - go through all (non-deleted) nodes & find one which overlaps the transformed position
   ✓ Load file:
	   - load nodes in temp. vec<Diatom>, importing any extra info from loaded definitions
       - load temporary GenericTree, using the temporary vector
       - convert the tree to Wrapper form, using the vec<Nodes>
       - translate the index references in the GT to those in the nodes vec
   ✓ Write out file:
       - if number of nodes without parents is > 1, put up error
       - otherwise, build a GT:
          - find top node, iterate through children, adding to nodes vector/allocator
          - also add to a nodes-pointers vector
*/


/*
  Node Definitions
  
  Built-in:
   - loaded by App Delegate
   - diatomized, so the diatom’s fields are the settable properties of the class
   - all are class-based nodes
 
  User-specific:
   - User can drop files onto Syncarp to add their own node definitions
   - Syncarp should save the paths of these files in the treedef, and re-try to load them
      - If cannot, then warn user and get new locations, quit, or remove the nodes with non-loaded types
   - Format:
      - Diatom file with 1 or more node definitions:
			nodeDefinitions:
				name:
					settable_property: 0...
				...
 
*/

#define nStr(prefix, str) (std::string(#prefix) + std::to_string(str))

@interface Document () {
	std::vector<Wrapper> nodes;
	std::map<void*, Diatom*> form_ctrl_to_settable_property_map;
	Wrapper *selectedNode;
    
    std::vector<Diatom> document_nodeDefs;
    
    std::vector<NodeDefFile> definition_files;
    
    BOOL should_initially_show_loader_window;
}

@property IBOutlet ScrollingTreeView *view_scrollingTree;
@property IBOutlet NSScrollView *view_nodeListContainer;
@property BuiltInNodeListView *view_nodeList;
@property IBOutlet NSScrollView *view_nodeOptions;

@property IBOutlet NSTextField *panel_label_nodeType;
@property IBOutlet NSTextField *panel_label_nodeDescr;
@property IBOutlet NSTextField *panel_label_optionsHeader;
@property IBOutlet NSBox *panel_hline_hdr;
@property IBOutlet NSBox *panel_hline_opts;
@property NSArray *panel_form_labels;
@property NSArray *panel_form_controls;

@property (strong, nonatomic) NodeLoaderWinCtrlr *nodeLoaderWC;

@end


@implementation Document


-(instancetype)init {
	if (self = [super init]) {
		selectedNode = NULL;
		_loaderIsOpen = NO;
        should_initially_show_loader_window = NO;
	}
	return self;
}

-(void)awakeFromNib {
	[self setSidePanelToEmpty];
}

-(void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    
    if (!self.view_nodeList) {
        self.view_nodeList = [[BuiltInNodeListView alloc] initWithFrame:self.view_nodeListContainer.frame];
        [self.view_nodeListContainer setDocumentView:self.view_nodeList];
    }
    
    if (!self.nodeLoaderWC) {
        self.nodeLoaderWC = [[NodeLoaderWinCtrlr alloc] initWithDoc:self];
        [self setUpFileDropCallback];
        if (should_initially_show_loader_window) {
            [self setLoaderIsOpen:YES];
            should_initially_show_loader_window = NO;
        }
    }
}

// Opening & closing the node def loader window
-(void)setLoaderIsOpen:(BOOL)loaderIsOpen {
	if (_loaderIsOpen == loaderIsOpen)
		return;
    
	_loaderIsOpen = loaderIsOpen;
    
    if (_loaderIsOpen) {
        [self.nodeLoaderWC showWindow:nil];
        [self.nodeLoaderWC.window makeKeyAndOrderFront:nil];
        [self addWindowController:self.nodeLoaderWC];
    }
    else {
        [self.nodeLoaderWC close];
        [self removeWindowController:self.nodeLoaderWC];
    }
}

// Opening & closing node options
-(void)setSidePanelToEmpty {
	self.panel_label_nodeType.stringValue = @"";
	self.panel_label_nodeDescr.stringValue = @"";
	self.panel_label_optionsHeader.hidden = YES;
	self.panel_hline_hdr.hidden = YES;
	self.panel_hline_opts.hidden = YES;
	
	for (id control in self.panel_form_controls) [control removeFromSuperview];
	for (id label   in self.panel_form_labels)   [label removeFromSuperview];
	self.panel_form_labels = nil;
	self.panel_form_controls = nil;
	
	form_ctrl_to_settable_property_map.clear();
}
NSString* nsstr(const std::string &s) {
	return [NSString stringWithFormat:@"%s", s.c_str()];
}
NSString* nsstr(Diatom &d) {
	return nsstr(d.value__string);
}
std::map<std::string, std::string>& getDescrs() {
	return *(std::map<std::string, std::string>*)node_descriptions;
}
std::vector<std::pair<std::string, Diatom*>> settablePropertiesForNode(Diatom &d) {
	std::vector<std::pair<std::string, Diatom*>> vec;
	d.each([&](std::string &prop_name, Diatom &d) {
		if (prop_name != "type" &&
			prop_name != "maxChildren" &&
			prop_name != "minChildren" &&
			prop_name != "posX" &&
			prop_name != "posY" &&
			prop_name != "original_type")
		{
			vec.push_back(make_pair(prop_name, &d));
		}
	});
	return vec;
}
-(void)setSidePanelToFilledOut {
	[self setSidePanelToEmpty];
	
	if (!selectedNode)
		return;
	
	Diatom &d = selectedNode->d;
	const auto &n_type = d["type"].value__string;
	auto n_desc = getDescrs()[n_type];
	if (n_type == "Unknown") {
		n_desc = std::string("Warning: type '") + d["original_type"].value__string + std::string("' is not loaded");
	}
	
	self.panel_label_nodeType.stringValue = nsstr(n_type);
	self.panel_label_nodeDescr.stringValue = nsstr(n_desc);
	self.panel_hline_hdr.hidden = NO;
	
	auto settables = settablePropertiesForNode(d);
	if (settables.size() == 0) {
		return;
	}
	
	self.panel_label_optionsHeader.hidden = NO;
	self.panel_hline_opts.hidden = NO;
	
	NSMutableArray *temp_controls = [[NSMutableArray alloc] init];
	NSMutableArray *temp_labels = [[NSMutableArray alloc] init];
	
	NSRect checkbox_frame = { 0, 0, 18, 18 };
	NSRect label_frame = { 0, 0, 180, 17 };
	NSRect control_frame = { 0, 0, 120, 19 };
	float vOffset = 125.;
	float hOffset_label = 8.;
	float hOffset_control = 102.;
	float vInc = 26.;
	
	int ind = 0;
	for (auto &i : settables) {
		Diatom &d = *i.second;
		float v = vOffset + ind * vInc;
		
		// Create label
		label_frame.origin = { hOffset_label, v };
		NSTextField *label = [[NSTextField alloc] initWithFrame:label_frame];
		label.stringValue = nsstr(i.first);
		label.font = [NSFont systemFontOfSize:13.]; //[NSFont fontWithName:@"PTSans-Regular" size:13.];
		label.textColor = [NSColor colorWithCalibratedRed:0.27 green:0.27 blue:0.26 alpha:1.0];
		[label setBezeled:NO];
		[temp_labels addObject:label];
		[self.view_nodeOptions addSubview:label];
		
		if (d.is_bool()) {
			// Create checkbox
			checkbox_frame.origin = { self.view_nodeOptions.frame.size.width - checkbox_frame.size.width - 14, v - 1 };
			NSButton *checkbox = [[NSButton alloc] initWithFrame:checkbox_frame];
			checkbox.target = self;
			checkbox.action = @selector(formButtonClicked:);
			if (d.value__bool) {
				checkbox.state = NSOnState;
			}
			[checkbox setButtonType:NSSwitchButton];
			[temp_controls addObject:checkbox];
			[self.view_nodeOptions addSubview:checkbox];
			form_ctrl_to_settable_property_map[(__bridge void*)checkbox] = i.second;
		}
		else if (d.is_string() || d.is_number()) {
			// Create string input
			control_frame.origin = { hOffset_control, v - 1 };
			NSTextField *control = [[NSTextField alloc] initWithFrame:control_frame];
			control.font = [NSFont systemFontOfSize:13.]; //[NSFont fontWithName:@"PTSans-Regular" size:11.];
			control.delegate = self;
			if (d.is_string()) {
				control.stringValue = nsstr(d);
			}
			else {
				control.doubleValue = d.value__number;
			}
			[temp_controls addObject:control];
			[self.view_nodeOptions addSubview:control];
			form_ctrl_to_settable_property_map[(__bridge void*)control] = i.second;
		}
		else {
			// Consider displaying an error message
		}
		++ind;
	}
	
	self.panel_form_controls = [NSArray arrayWithArray:temp_controls];
	self.panel_form_labels = [NSArray arrayWithArray:temp_labels];
}
-(void)controlTextDidChange:(NSNotification *)notif {
	Diatom &d = *(form_ctrl_to_settable_property_map[(__bridge void*)notif.object]);
	if (d.is_string()) {
		d = [[notif.object stringValue] UTF8String];
	}
	else {
		d = [[notif.object stringValue] doubleValue];
	}
}
-(void)formButtonClicked:(NSButton*)button {
	Diatom &d = *(form_ctrl_to_settable_property_map[(__bridge void*)button]);
	d = (bool) button.state;
}


+(BOOL)autosavesInPlace { return NO; }
-(NSString *)windowNibName { return @"Document"; }
-(void*)getNodes { return &nodes; }
-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }

-(BOOL)nodeIsOrphan_byIndex:(int)i {
	const Wrapper &n = nodes[i];
	for (const auto &m : nodes) {
		if (&n == &m) {
			continue;
		}
		for (auto c : m.children) {
			if (c == i) {
				return false;
			}
		}
	}
	return true;
}
-(BOOL)nodeIsOrphan:(Wrapper*)n {
	return [self nodeIsOrphan_byIndex:index_in_vec(nodes, n)];
}
-(BOOL)node:(Wrapper*)A isAncestorOf:(Wrapper*)B {
	while ((B = [self parentOfNode:B])) {
		if (B == A) {
			return true;
		}
	}
	return false;
}

-(Wrapper*)parentOfNode:(Wrapper*)n {
	int ni = index_in_vec(nodes, n);
	
	for (auto &i : nodes) {
		for (auto j : i.children) {
			if (j == ni) {
				return &i;
			}
		}
	}
	
	return NULL;
}


-(int)nNodesWithoutParents {
	int n_orphans = 0;
	
	for (auto &n : nodes) {
		if (n.destroyed)            { continue; }
		if ([self nodeIsOrphan:&n]) { ++n_orphans; }
	}
	
	return n_orphans;
}

-(Wrapper*)topNode {
	Wrapper *top = NULL;
	
	int i=0;
	for (auto &n : nodes) {
		if (n.destroyed) {
			continue;
		}
		
		int n_parents = 0;
		for (const auto &m : nodes) {
			if (&n == &m) {
				continue;
			}
			for (auto c : m.children) {
				if (c == i) {
					n_parents += 1;
				}
			}
		}
		if (n_parents == 0) {
			top = &n;
			break;
		}
		++i;
	}
	
	return top;
}


-(void)detachNodeFromTree:(Wrapper*)n {
	int ind = index_in_vec(nodes, n);
	assert(ind >= 0 && ind < nodes.size());
	for (auto &i : nodes) {
		std::vector<int> ch_new;
		for (auto ch : i.children) {
			if (ch != ind) {
				ch_new.push_back(ch);
			}
		}
		i.children = ch_new;
	}
}
-(void)destroyNode:(Wrapper*)n {
	[self detachNodeFromTree:n];
	n->children.clear();
	n->destroyed = true;
}
-(void)addNode:(Wrapper*)n {
	nodes.push_back(*n);
}
-(Wrapper*)addNodeOfType:(NSString*)type at:(NSPoint)p {
	const char *t = [type UTF8String];
	Diatom new_node = [self getNodeWithType:t];
	new_node["posX"] = p.x;
	new_node["posY"] = p.y;

	Wrapper w = {
		new_node,
		{ },
		false
	};
	nodes.push_back(w);
	return &nodes.back();
}
-(void)makeNode:(Wrapper*)A childOf:(Wrapper*)B atIndex:(int)i {
	auto &ch = B->children;
	assert(i >= 0 && i <= ch.size());

	[self detachNodeFromTree:A];
	auto it = ch.begin() + i;
	ch.insert(it, index_in_vec(nodes, A));
}


-(void)setSelectedNode:(Wrapper*)n {
	selectedNode = n;
	if (n) [self setSidePanelToFilledOut];
	else   [self setSidePanelToEmpty];
}



// Saving treedef file

-(NSData*)dataOfType:(NSString*)typeName error:(NSError**)outError {
	using Str = std::string;
	
	if ([self nNodesWithoutParents] > 1) {
		NSString *msg = @"The document can’t currently be saved, as it contains orphaned nodes.";
		*outError = [NSError errorWithDomain:@"" code:0
									userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
		return nil;
	}
	
    Diatom d;
    
    // Save definition file locations, if present
    if (definition_files.size() > 0) {
        Diatom &df = d["definitionFiles"] = Diatom();
        for (size_t i=0, n = definition_files.size(); i < n; ++i) {
            df[nStr(f, i)] = definition_files[i].path;
        }
    }
    
	// Repack the nodes into nodes_diatom_ptrs, and build a tree
	Wrapper *top = [self topNode];
	if (top == NULL) {
		d["treeDef"] = Diatom();
		d["treeDef"]["nodes"] = Diatom();
		d["treeDef"]["tree"] = Diatom();
		d["treeDef"]["tree"]["tree"] = Diatom();
		d["treeDef"]["tree"]["free_list"] = Diatom();
		Str str = diatom__serialize(d);
		return [NSData dataWithBytes:str.c_str() length:str.size()];
	}
	
	std::vector<Diatom*> nodes_diatom_ptrs;
	GenericTree<Diatom> tree;
	std::map<int, int> index_translation_map;
	std::vector<std::vector<int>> children_nodeinds;
	
	walk(nodes, *top, [&](Wrapper &w) {
		nodes_diatom_ptrs.push_back(new Diatom(w.d));
		children_nodeinds.push_back(w.children);
		int index_in_nodes = index_in_vec(nodes, &w);
		int index_in_diatoms = (int) nodes_diatom_ptrs.size() - 1;
		index_translation_map[index_in_nodes] = index_in_diatoms;
		
		Diatom &d = *nodes_diatom_ptrs.back();		// Scrub extra Diatom fields
		d["minChildren"] = Diatom{Diatom::Type::Empty};
		d["maxChildren"] = Diatom{Diatom::Type::Empty};
	});

	int i=0;
	for (auto &ch_inds : children_nodeinds) {
		if (i == 0)
			tree.addNode(*nodes_diatom_ptrs[0], NULL);
		
		Diatom *parent = nodes_diatom_ptrs[i];
		for (int c : ch_inds) {
			Diatom *node_ptr = nodes_diatom_ptrs[index_translation_map[c]];
			tree.addNode(*node_ptr, parent);
		}
		
		++i;
	}
    d["treeDef"] = Diatom();
    
	d["treeDef"]["tree"] = tree.toDiatom(nodes_diatom_ptrs);
	std::string trstr = diatom__serialize(d);
	
	d["treeDef"]["nodes"] = Diatom();
	for (int i=0; i < nodes_diatom_ptrs.size(); ++i) {
		Diatom *n = nodes_diatom_ptrs[i];
		d["treeDef"]["nodes"][nStr(n, i)] = *n;
		delete n;
	}
	
	std::string str = diatom__serialize(d);
	
	return [NSData dataWithBytes:str.c_str() length:str.size()];
}


// Loading treedef file

std::string read_file(std::string filename) {
	std::ifstream file_stream(filename);
	return std::string(
		(std::istreambuf_iterator<char>(file_stream)),
		std::istreambuf_iterator<char>()
	);
}

-(BOOL)readFromData:(NSData*)data ofType:(NSString*)typeName error:(NSError**)outError {
	NSLog(@"readFromData");
	NSString *nsstr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!nsstr) {
		NSString *msg = @"Couldn't convert the file to a string.";
		*outError = [NSError errorWithDomain:@"" code:0
									userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
		return NO;
	}

	auto s = read_file([nsstr UTF8String]);
	auto result = diatom__unserialize(s);
	Diatom d = Diatom{Diatom::Type::Empty};
	
	std::vector<std::string> unknown_node_types;
	std::vector<std::string> unknown_node_properties;
	
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
																	userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"treeDef\" object." }];
			return NO;
		}
		if (!d["treeDef"]["nodes"].is_table()) {
			*outError = [NSError errorWithDomain:@"" code:0
																	userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"nodes\" object." }];
			return NO;
		}
		if (!d["treeDef"]["tree"].is_table()) {
			*outError = [NSError errorWithDomain:@"" code:0
																	userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"valid tree\" object." }];
			return NO;
		}
	}
    
    // Load document-level node definition files
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
				putUpError(@"Node definition files missing",
						   @"You should fix this by reconnecting them in the Node Loader window");
				should_initially_show_loader_window = YES;
				break;
			}
		}
	}
    
	
	try {
		std::vector<Diatom*> nodes_diatom_ptrs;
		
		// Load the nodes vector from treeDef.nodes
		d["treeDef"]["nodes"].each([&](std::string &key, Diatom &n) {
			// If the node is in the registry, add its min/max children as properties
			// If not, add a dummy node
			const std::string &ntype = n["type"].value__string;
			
			Diatom node_definition = [self getNodeWithType:ntype.c_str()];
			if (node_definition.is_empty()) {
				Diatom stand_in;
				stand_in["type"] = "Unknown";
				stand_in["original_type"] = ntype;
				
				nodes_diatom_ptrs.push_back(new Diatom(stand_in));
				unknown_node_types.push_back(ntype);
			}
			else {
				Diatom *copy = new Diatom(n);
				(*copy)["minChildren"] = node_definition["minChildren"];
				(*copy)["maxChildren"] = node_definition["maxChildren"];
				nodes_diatom_ptrs.push_back(copy);
				
				// If the node has properties that are not defined in the node definition,
				// alert the user
				n.each([&](std::string &k, Diatom &d) {
					if (k != "posX" && k != "posY") {
						if (node_definition[k].is_empty()) {
							unknown_node_properties.push_back(ntype + std::string("/") + k);
						}
					}
				});
			}
		});
		
		// Load the tree, referring to the nodes list
		{
			GenericTree<Diatom> tree;
			tree.fromDiatom(d["treeDef"]["tree"], nodes_diatom_ptrs);
			
			// Convert tree to wrapper form
			std::map<int, int> index_translation_map;
			int i=0;
			tree.walk([&](Diatom *d, int index) {
				Wrapper n = {*d, tree.children(index), false};
				nodes.push_back(n);
				index_translation_map[index] = i++;
				
				printf("added node of type %s, indices %d->%d with children ", n.d["type"].value__string.c_str(), index, i-1);
				for (int c : n.children) {
					printf("%d ", c);
				}
				printf("\n");
			});
			// Also convert all child indices to those in the new Diatoms vector
			i=0;
			for (auto &n : nodes) {
				printf("new children for node %d: ", i);
				int j=0;
				for (auto c : n.children) {
					n.children[j++] = index_translation_map[c];
					printf("%d ", n.children[j-1]);
				}
				printf("\n");
				++i;
			}
		}
		
		// Destroy temporary vector
		for (auto i : nodes_diatom_ptrs) {
			delete i;
		}
	}
	catch (const std::runtime_error &exc) {
		NSString *msg = [NSString stringWithFormat:@"%s.", exc.what()];
		*outError = [NSError errorWithDomain:@"" code:0
									userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
		return NO;
	}
	
	if (unknown_node_types.size() > 0) {
        putUpError(@"Warning: unknown node types detected",
                   @"You should load the requisite node definition files in the Node Loader window.");
        should_initially_show_loader_window = YES;
	}
	if (unknown_node_properties.size() > 0) {
		for (auto &s : unknown_node_properties) {
			NSLog(@"Unknown node properties: %s", s.c_str());
		}
	}
	
	return YES;
}


-(Diatom)getNodeWithType:(const char *)type {
    for (auto &def : document_nodeDefs)
        if (def["type"].value__string == type) {
            Diatom new_node = def;
            return new_node;
        }
    
    return [self.appDelegate getNodeWithType:type];
}

-(void*)nodeDefs {
    return (void*) &document_nodeDefs;
}

-(void*)getAllNodeDefs {
    std::vector<Diatom> *all = new std::vector<Diatom>;
    
	for (auto &i : document_nodeDefs) {
		all->push_back(i);
	}
    
	auto built_ins = (std::vector<Diatom>*) self.appDelegate.builtInNodes;
	if (built_ins) {
		// BROKEN?!!
		for (auto &i : *built_ins) {
				all->push_back(i);
		}
	}
    
	return all;
}

-(void*)getDefinitionFiles {
    return &definition_files;
}

-(void)addNodeDef:(Diatom)def {
    auto defs = (std::vector<Diatom>*) self.nodeDefs;
    defs->push_back(def);
}
-(BOOL)addNodeDef_FromFile:(NSString*)path {
	definition_files.push_back({ [path UTF8String], false });

	auto s = read_file([path UTF8String]);
	auto result = diatom__unserialize(s);
	auto &d = result.d;

	if (!(result.success && d.is_table() && d["nodeDef"].is_table() && d["nodeDef"]["type"].is_string())) {
		return NO;
	}
    
	definition_files.back().succeeded = true;
	[self addNodeDef:d["nodeDef"]];
	return YES;
}

-(void)setUpFileDropCallback {
	// Load dropped nodes as Diatoms
	__unsafe_unretained typeof(self) weakSelf = self;
	[self.nodeLoaderWC setCB:^(NSArray *files) {
		// - Get list of .diatom files containing node definitions
		// - Load each file into a Diatom object
		//    - If any fail, add to errors
		// - Ensure each has the required properties:
		//    - type
		//    - any options w/ defaults
        
		[weakSelf.nodeLoaderWC disp];
        
		NSMutableArray *failed = [NSMutableArray array];
        
		for (NSString *file in files) {
			BOOL res = [weakSelf addNodeDef_FromFile:file];
			if (!res) {
				[failed addObject:file];
			}
		}

		[weakSelf.view_nodeList setNeedsDisplay:YES];

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
