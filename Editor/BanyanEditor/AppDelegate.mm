#import "AppDelegate.h"
#include "Banyan.h"
#include "DiatomSerialization.h"
#include "Document.h"

@interface AppDelegate () {
  std::map<std::string, std::string> nodeDescriptions;
}

@end


@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Load built-in Nodes (as Diatoms)
  Banyan::TreeDefinition::registerBuiltins();

  std::vector<Diatom> defs;
  std::transform(Banyan::NodeRegistry::definitions().begin(),
                 Banyan::NodeRegistry::definitions().end(),
                 std::back_inserter(defs),
                 [&](Banyan::NodeSuper *node) -> Diatom {
    Diatom d = node->__to_diatom();
    d["minChildren"] = (double) node->childLimits().min;
    d["maxChildren"] = (double) node->childLimits().max;
    return d;
  });
  self.nodeDefs = defs;

  nodeDescriptions = {
    { "Inverter",  "Inverts child's return status"     },
    { "Repeater",  "Calls child N times"               },
    { "Succeeder", "Always returns success"            },
    { "Sequence",  "Calls children in order"           },
    { "Selector",  "Calls children until one succeeds" },
    { "While",     "Calls second while first succeeds" },
  };
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
  // Insert code here to tear down your application
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return NO;
}

-(std::map<std::string, std::string>&)descriptions {
  return nodeDescriptions;
}

-(IBAction)menu__zoomIn:(id)sender {
  [[NSDocumentController.sharedDocumentController currentDocument] zoomIn];
}
-(IBAction)menu__zoomOut:(id)sender {
  [[NSDocumentController.sharedDocumentController currentDocument] zoomOut];
}

@end

