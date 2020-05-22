//
//  AppDelegate.m
//  Thingumy
//
//  Created by Ben on 19/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "AppDelegate.h"
#import "DragDestView.h"
#include "Banyan.h"
#include "Diatom.h"
#include "Diatom-Storage.h"

@interface AppDelegate () {
	std::vector<Diatom> *nodeDefs;
}

@property IBOutlet NSWindow *nodeDefsWindow;
@property IBOutlet DragDestView *dragDestView;

@end


@implementation AppDelegate

void putUpError(NSString *title, NSString *detail) {
	NSError *err = [NSError errorWithDomain:@"" code:1257
								   userInfo:@{
											  NSLocalizedDescriptionKey: title,
											  NSLocalizedRecoverySuggestionErrorKey: detail
											  }];
	[[NSAlert alertWithError:err] runModal];
}

-(void*)builtInNodes {
	return nodeDefs;
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	nodeDefs = new std::vector<Diatom>;
	
	// Load built-in Nodes (as Diatoms)
	Banyan::TreeDefinition::registerBuiltins();
	
	for (auto &nw : Banyan::NodeRegistry::definitions()) {
		Banyan::NodeBase *n = nw->node;
		Diatom d = diatomize(n->_getSD());
		d["minChildren"] = (double) nw->node->childLimits().min;
		d["maxChildren"] = (double) nw->node->childLimits().max;
		nodeDefs->push_back(d);
	}
	
	// Load dropped nodes (as Diatoms)
	__unsafe_unretained typeof(self) weakSelf = self;
	[self.dragDestView setFileDropCallback:^(NSArray *files) {
		// - Get list of .diatom files containing node definitions
		// - Load each file into a Diatom object
		//    - If any fail, add to errors
		// - Ensure each has the required properties:
		//    - type
		//    - any options w/ defaults
		
		NSMutableArray *failed = [NSMutableArray array];
		
		for (NSString *file in files) {
			Diatom d = diatomFromFile([file UTF8String]);
			if (d.isNil()) [failed addObject:file];
			else if (!d["nodeDef"].isTable())          [failed addObject:file];
			else if (!d["nodeDef"]["type"].isString()) [failed addObject:file];
			else {
				auto defs = (std::vector<Diatom>*)weakSelf.builtInNodes;
				defs->push_back(d);
			}
		}
		
		if (nodeDefs->size() == 0) {
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

-(Diatom)getNodeWithType:(const char *)type {
	for (auto &def : *nodeDefs)
		if (def["type"].str_value() == type) {
			Diatom new_node = def;
			if (def["minChildren"].isNumber())
				new_node["minChildren"] = def["minChildren"],
				new_node["maxChildren"] = def["maxChildren"];
			return new_node;
		}
	
	return Diatom::NilObject();
}


-(void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return NO;
}

@end
