#import "AppDelegate.h"
#import "DragDestView.h"
#include "Banyan/Banyan.h"
#include "Banyan/GenericTree/Diatom/DiatomSerialization.h"
#include "Document.h"

@interface AppDelegate () {
  std::vector<Diatom> *nodeDefs;
}

@property IBOutlet NSMenuItem *menu__show_node_loader;

@end


@implementation AppDelegate

-(void*)builtInNodes {
  return nodeDefs;
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  nodeDefs = new std::vector<Diatom>;
  self.menu__show_node_loader.target = self;
  self.menu__show_node_loader.action = @selector(showLoader:);

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
  for (auto &def : *nodeDefs) {
    if (def["type"].value__string == type) {
      Diatom new_node = def;
      return new_node;
    }
  }

  return Diatom{Diatom::Type::Empty};
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
    self.menu__show_node_loader.state = doc.loaderWinOpen;
  }
  return doc != nil;
}

-(void)showLoader:(id)sender {
  Document *doc = [[NSDocumentController sharedDocumentController] currentDocument];
  doc.loaderWinOpen = !doc.loaderWinOpen;
}

@end

