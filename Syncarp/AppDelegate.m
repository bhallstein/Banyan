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
#include "Document.h"

@interface AppDelegate () {
	std::vector<Diatom> *nodeDefs;
}

@property IBOutlet NSMenuItem *menuitem_ShowNodeLoader;

@end


@implementation AppDelegate

-(void*)builtInNodes {
	return nodeDefs;
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	nodeDefs = new std::vector<Diatom>;
	self.menuitem_ShowNodeLoader.target = self;
	self.menuitem_ShowNodeLoader.action = @selector(showLoader:);
	
	// Load built-in Nodes (as Diatoms)
	Banyan::TreeDefinition::registerBuiltins();
	
	for (auto &nw : Banyan::NodeRegistry::definitions()) {
		Banyan::NodeBase *n = nw->node;
		Diatom d = diatomize(n->_getSD());
		d["minChildren"] = (double) nw->node->childLimits().min;
		d["maxChildren"] = (double) nw->node->childLimits().max;
		nodeDefs->push_back(d);
	}
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

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	Document *doc = [[NSDocumentController sharedDocumentController] currentDocument];
	if (doc) {
		self.menuitem_ShowNodeLoader.state = doc.loaderIsOpen;
	}
	return doc != nil;
}

-(void)showLoader:(id)sender {
	Document *doc = [[NSDocumentController sharedDocumentController] currentDocument];
	doc.loaderIsOpen = !doc.loaderIsOpen;
}

@end
