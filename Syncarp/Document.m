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
#include "Wrapper.h"
#include "BuiltInNodeListView.h"

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
}

@property IBOutlet ScrollingTreeView *scrollingTreeView;
@property IBOutlet NSScrollView *nodeSelectorView;
@property BuiltInNodeListView *nodeListView;

@end


@implementation Document

-(instancetype)init { return [super init]; }
+(BOOL)autosavesInPlace { return NO; }
-(NSString *)windowNibName { return @"Document"; }
-(void*)getNodes { return &nodes; }
-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }

-(int)nNodesWithoutParents {
	int n_orphans = 0;
	int i = 0;
	
	std::map<int, int> parentCounts;
	
	for (const auto &n : nodes) {
		if (n.destroyed) continue;
		
		// Find the number of other nodes that are parents of N
		int n_parents = 0;
		for (const auto &m : nodes) {
			if (&n == &m) continue;
			for (auto c : m.children) if (c == i) n_parents += 1;
		}
		if (n_parents == 0) ++n_orphans;
		++i;
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
	
	self.nodeListView = [[BuiltInNodeListView alloc] initWithFrame:self.nodeSelectorView.frame];
	[self.nodeSelectorView setDocumentView:self.nodeListView];
}


template<class T>
int indexOfNode(std::vector<T> &vec, T *t) {
	return int(t - &vec[0]);
}
-(void)detachNodeFromTree:(Wrapper*)n {
	int ind = indexOfNode(nodes, n);
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
-(void)addNodeOfType:(NSString*)type at:(NSPoint)p {
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
}
-(void)makeNode:(Wrapper*)A childOf:(Wrapper*)B {
	[self detachNodeFromTree:A];
	B->children.push_back(indexOfNode(nodes, A));
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
		int index_in_nodes = indexOfNode(nodes, &w);
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
			
			const std::string &ntype = i.second["type"].str_value();
			
			Diatom d = [self.appDelegate getNodeWithType:ntype.c_str()];
			if (d.isNil()) {
				Diatom stand_in;
				stand_in["type"] = "Unknown";
				stand_in["original_type"] = ntype;
				
				nodes_diatom_ptrs.push_back(new Diatom(stand_in));
				unknown_node_types.push_back(ntype);
			}
			else
				nodes_diatom_ptrs.push_back(new Diatom(d));
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
	
	return YES;
}

@end
