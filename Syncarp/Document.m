//
//  Document.m
//  Thingumy
//
//  Created by Ben on 19/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "Document.h"
#include "Diatom.h"
#include "Diatom-Storage.h"
#include "Banyan.h"
#import "ScrollingTreeView.h"
#import "AppDelegate.h"
#import "Helpers.h"
#include "Wrapper.h"
#include "BuiltInNodeListView.h"
#include "NodeLoaderWinCtrlr.h"

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

@interface Document () {
	std::vector<Wrapper> nodes;
	std::map<void*, Diatom*> form_ctrl_to_settable_property_map;
	Wrapper *selectedNode;
    
    std::vector<Diatom> document_nodeDefs;
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
	}
	return self;
}

-(void)awakeFromNib {
	[self setSidePanelToEmpty];
    self.nodeLoaderWC = [[NodeLoaderWinCtrlr alloc] init];
    [self setUpFileDropCallback];
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
	return nsstr(d.str_value());
}
std::map<std::string, std::string>& getDescrs() {
	return *(std::map<std::string, std::string>*)node_descriptions;
}
std::vector<std::pair<std::string, Diatom*>> settablePropertiesForNode(Diatom &d) {
	std::vector<std::pair<std::string, Diatom*>> vec;
	for (auto &i : d.descendants()) {
		const auto &prop_name = i.first;
		if (prop_name == "type" ||
			prop_name == "maxChildren" ||
			prop_name == "minChildren" ||
			prop_name == "posX" ||
			prop_name == "posY" ||
			prop_name == "original_type")
			continue;
		vec.push_back(make_pair(i.first, &i.second));
	}
	return vec;
}
-(void)setSidePanelToFilledOut {
	[self setSidePanelToEmpty];
	
	if (!selectedNode)
		return;
	
	Diatom &d = selectedNode->d;
	const auto &n_type = d["type"].str_value();
	auto n_desc = getDescrs()[n_type];
	if (n_type == "Unknown")
		n_desc = std::string("Type '") + d["original_type"].str_value() + std::string("' is not loaded");
	
	self.panel_label_nodeType.stringValue = nsstr(n_type);
	self.panel_label_nodeDescr.stringValue = nsstr(n_desc);
	self.panel_hline_hdr.hidden = NO;
	
	auto settables = settablePropertiesForNode(d);
	if (settables.size() == 0)
		return;
	
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
		label.font = [NSFont fontWithName:@"PTSans-Regular" size:13.];
		label.textColor = [NSColor colorWithCalibratedRed:0.27 green:0.27 blue:0.26 alpha:1.0];
		[label setBezeled:NO];
		[temp_labels addObject:label];
		[self.view_nodeOptions addSubview:label];
		
		if (d.isBool()) {
			// Create checkbox
			checkbox_frame.origin = { self.view_nodeOptions.frame.size.width - checkbox_frame.size.width - 14, v - 1 };
			NSButton *checkbox = [[NSButton alloc] initWithFrame:checkbox_frame];
			checkbox.target = self;
			checkbox.action = @selector(formButtonClicked:);
			if (d.bool_value())
				checkbox.state = NSOnState;
			[checkbox setButtonType:NSSwitchButton];
			[temp_controls addObject:checkbox];
			[self.view_nodeOptions addSubview:checkbox];
			form_ctrl_to_settable_property_map[(__bridge void*)checkbox] = i.second;
		}
		else {
			// Create string input
			control_frame.origin = { hOffset_control, v - 1 };
			NSTextField *control = [[NSTextField alloc] initWithFrame:control_frame];
			control.font = [NSFont fontWithName:@"PTSans-Regular" size:11.];
			control.delegate = self;
			if (d.isString())
				control.stringValue = nsstr(d);
			else
				control.doubleValue = d.number_value();
			[temp_controls addObject:control];
			[self.view_nodeOptions addSubview:control];
			
			form_ctrl_to_settable_property_map[(__bridge void*)control] = i.second;
		}
		++ind;
	}
	
	self.panel_form_controls = [NSArray arrayWithArray:temp_controls];
	self.panel_form_labels = [NSArray arrayWithArray:temp_labels];
}
-(void)controlTextDidChange:(NSNotification *)notif {
	Diatom &d = *(form_ctrl_to_settable_property_map[(__bridge void*)notif.object]);
	if (d.isString())
		d = [[notif.object stringValue] UTF8String];
	else
		d = [[notif.object stringValue] doubleValue];
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
		if (&n == &m) continue;
		for (auto c : m.children)
			if (c == i)
				return false;
	}
	return true;
}
-(BOOL)nodeIsOrphan:(Wrapper*)n {
	return [self nodeIsOrphan_byIndex:index_in_vec(nodes, n)];
}
-(BOOL)node:(Wrapper*)A isAncestorOf:(Wrapper*)B {
	while ((B = [self parentOfNode:B]))
		if (B == A)
			return true;
	return false;
}

-(Wrapper*)parentOfNode:(Wrapper*)n {
	int ni = index_in_vec(nodes, n);
	
	for (auto &i : nodes)
		for (auto j : i.children)
			if (j == ni)
				return &i;
	
	return NULL;
}


-(int)nNodesWithoutParents {
	int n_orphans = 0;
	
	for (auto &n : nodes) {
		if (n.destroyed) continue;
		if ([self nodeIsOrphan:&n]) ++n_orphans;
	}
	
	return n_orphans;
}

-(Wrapper*)topNode {
	Wrapper *top = NULL;
	
	int i=0;
	for (auto &n : nodes) {
		if (n.destroyed) continue;
		
		int n_parents = 0;
		for (const auto &m : nodes) {
			if (&n == &m) continue;
			for (auto c : m.children) if (c == i) n_parents += 1;
		}
		if (n_parents == 0) {
			top = &n;
			break;
		}
		++i;
	}
	
	return top;
}

-(void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[super windowControllerDidLoadNib:aController];
	
	self.view_nodeList = [[BuiltInNodeListView alloc] initWithFrame:self.view_nodeListContainer.frame];
	[self.view_nodeListContainer setDocumentView:self.view_nodeList];
}


-(void)detachNodeFromTree:(Wrapper*)n {
	int ind = index_in_vec(nodes, n);
	assert(ind >= 0 && ind < nodes.size());
	for (auto &i : nodes) {
		std::vector<int> ch_new;
		for (auto ch : i.children)
			if (ch != ind)
				ch_new.push_back(ch);
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
	Diatom new_node = [self.appDelegate getNodeWithType:t];
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
	
	// Repack the nodes into nodes_diatom_ptrs, and build a tree
	Wrapper *top = [self topNode];
	if (top == NULL) {
		Diatom d;
		d["nodes"] = Diatom();
		d["tree"] = Diatom();
		d["tree"]["tree"] = Diatom();
		d["tree"]["free_list"] = Diatom();
		Str str = diatomToString(d, "treeDef");
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
		d["minChildren"] = Diatom::NilObject();
		d["maxChildren"] = Diatom::NilObject();
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
	Diatom d;
	d["tree"] = tree.toDiatom(nodes_diatom_ptrs);
	std::string trstr = diatomToString(d, "treeDef");
//	printf("TRSTR: %s\n", trstr.c_str());
	
	d["nodes"] = Diatom();
	for (int i=0; i < nodes_diatom_ptrs.size(); ++i) {
		Diatom *n = nodes_diatom_ptrs[i];
		d["nodes"][Str("n") + std::to_string(i)] = *n;
		delete n;
	}
	
	std::string str = diatomToString(d, "treeDef");
	
	return [NSData dataWithBytes:str.c_str() length:str.size()];
}


// Loading treedef file

-(BOOL)readFromData:(NSData*)data ofType:(NSString*)typeName error:(NSError**)outError {
	NSLog(@"readFromData");
	NSString *nsstr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!nsstr) {
		NSString *msg = @"Couldn't convert the file to a string.";
		*outError = [NSError errorWithDomain:@"" code:0
									userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
		return NO;
	}
	
	Diatom d = diatomFromString([nsstr UTF8String]);
	
	std::vector<std::string> unknown_node_types;
	std::vector<std::string> unknown_node_properties;
	
	// Checks
	{
		// Check diatom loaded
		if (d.isNil()) {
			*outError = [NSError errorWithDomain:@"" code:0
										userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The file is not a valid .diatom file." }];
			return NO;
		}
		
		// Check has required parts
		if (!d["treeDef"].isTable()) {
			if (d.isNil()) {
				*outError = [NSError errorWithDomain:@"" code:0
											userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"treeDef\" object." }];
				return NO;
			}
		}
		if (!d["treeDef"]["nodes"].isTable()) {
			if (d.isNil()) {
				*outError = [NSError errorWithDomain:@"" code:0
											userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"nodes\" object." }];
				return NO;
			}
		}
		if (!d["treeDef"]["tree"].isTable()) {
			if (d.isNil()) {
				*outError = [NSError errorWithDomain:@"" code:0
											userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: @"The .diatom file did not contain a \"valid tree\" object." }];
				return NO;
			}
		}
	}
	
	try {
		std::vector<Diatom*> nodes_diatom_ptrs;
		
		// Load the nodes vector from treeDef.nodes
		for (auto i : d["treeDef"]["nodes"].descendants()) {
			// If the node is in the registry, add its min/max children as properties
			// If not, add a dummy node
			
			Diatom n = i.second;
			const std::string &ntype = i.second["type"].str_value();
			
			Diatom node_definition = [self.appDelegate getNodeWithType:ntype.c_str()];
			if (node_definition.isNil()) {
				Diatom stand_in;
				stand_in["type"] = "Unknown";
				stand_in["original_type"] = ntype;
				
				nodes_diatom_ptrs.push_back(new Diatom(stand_in));
				unknown_node_types.push_back(ntype);
			}
			else {
				nodes_diatom_ptrs.push_back(new Diatom(i.second));
				
				// If the node in the tree has properties that are not defined in the node definition,
				// alert the user
				for (auto &j : n.descendants())
					if (node_definition[j.first].isNil())
						unknown_node_properties.push_back(ntype + std::string("/") + j.first);
			}
		}
		
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
				
				printf("added node of type %s, indices %d->%d with children ", n.d["type"].str_value().c_str(), index, i-1);
				for (int c : n.children) printf("%d ", c);
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
		for (auto i : nodes_diatom_ptrs) delete i;
	}
	catch (const std::runtime_error &exc) {
		NSString *msg = [NSString stringWithFormat:@"%s.", exc.what()];
		*outError = [NSError errorWithDomain:@"" code:0
									userInfo:@{ NSLocalizedRecoverySuggestionErrorKey: msg }];
		return NO;
	}
	
	if (unknown_node_types.size() > 0) {
		// Show a kind of warning and let user select replacement definition
		// files
	}
	if (unknown_node_properties.size() > 0) {
		for (auto &s : unknown_node_properties)
			NSLog(@"Unknown node properties: %s", s.c_str());
	}
	
	return YES;
}


-(Diatom)getNodeWithType:(const char *)type {
    for (auto &def : document_nodeDefs)
        if (def["type"].str_value() == type) {
            Diatom new_node = def;
            if (def["minChildren"].isNumber())
                new_node["minChildren"] = def["minChildren"],
                new_node["maxChildren"] = def["maxChildren"];
            return new_node;
        }
    
    return [self.appDelegate getNodeWithType:type];
}

-(void*)nodeDefs {
    return (void*) &document_nodeDefs;
}

-(void*)getAllNodeDefs {
    std::vector<Diatom> *all = new std::vector<Diatom>;
    
    for (auto &i : document_nodeDefs)
        all->push_back(i);
    
    auto built_ins = (std::vector<Diatom>*) self.appDelegate.builtInNodes;
    for (auto &i : *built_ins)
        all->push_back(i);
    
    return all;
}

-(void)setUpFileDropCallback {
    // Load dropped nodes (as Diatoms)
    __unsafe_unretained typeof(self) weakSelf = self;
    [self.nodeLoaderWC setCB:^(NSArray *files) {
        // - Get list of .diatom files containing node definitions
        // - Load each file into a Diatom object
        //    - If any fail, add to errors
        // - Ensure each has the required properties:
        //    - type
        //    - any options w/ defaults
        
        NSMutableArray *failed = [NSMutableArray array];
        auto *defs = (std::vector<Diatom>*) weakSelf.nodeDefs;
        
        for (NSString *file in files) {
            Diatom d = diatomFromFile([file UTF8String]);
            if (d.isNil()) [failed addObject:file];
            else if (!d["nodeDef"].isTable())          [failed addObject:file];
            else if (!d["nodeDef"]["type"].isString()) [failed addObject:file];
            else {
                defs->push_back(d["nodeDef"]);
            }
        }
        
        [weakSelf.view_nodeList setNeedsDisplay:YES];
        
        if ([failed count] != 0) {
            NSMutableString *errFilesList = [[NSMutableString alloc] init];
            for (int i=0; i < failed.count; ++i)
                [errFilesList appendFormat:@"\n %@", failed[i]];
            NSString *errStr = [NSString stringWithFormat:@"%@ %@",
                                @"The following definition files were invalid:", errFilesList];
            putUpError(@"Error loading node definitions", errStr);
            return;
        }
    }];
}

@end
