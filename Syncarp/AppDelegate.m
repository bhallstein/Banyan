#import "AppDelegate.h"
#import "DragDestView.h"
#include "Banyan/Banyan.h"
#include "Banyan/GenericTree/Diatom/DiatomSerialization.h"
#include "Document.h"

@interface AppDelegate () {
  std::vector<Diatom> nodeDefs;
  std::map<std::string, std::string> nodeDescriptions;
}

@property IBOutlet NSMenuItem *menu__show_node_loader;

@end


@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  self.menu__show_node_loader.target = self;
  self.menu__show_node_loader.action = @selector(showLoader:);

  // Load built-in Nodes (as Diatoms)
  Banyan::TreeDefinition::registerBuiltins();
  nodeDescriptions = {
    { "Inverter",  "Inverts child's return status"     },
    { "Repeater",  "Calls child N times"               },
    { "Succeeder", "Always returns success"            },
    { "Sequence",  "Calls children in order"           },
    { "Selector",  "Calls children until one succeeds" },
    { "While",     "Calls second while first succeeds" },
  };

  for (auto &nw : Banyan::NodeRegistry::definitions()) {
    Banyan::NodeBase *n = nw->node;
    Diatom d = diatomize(n->_getSD());
    d["minChildren"] = (double) nw->node->childLimits().min;   // Todo: not do this
    d["maxChildren"] = (double) nw->node->childLimits().max;
    nodeDefs.push_back(d);
  }
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

-(std::vector<Diatom>)builtinNodeDefs {
  return nodeDefs;
}

-(std::map<std::string, std::string>&)descriptions {
  return nodeDescriptions;
}

@end

