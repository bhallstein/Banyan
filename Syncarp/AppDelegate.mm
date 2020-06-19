#import "AppDelegate.h"
#include "Banyan/Banyan.h"
#include "Banyan/GenericTree/Diatom/DiatomSerialization.h"
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
                 [&](Banyan::NodeRegistry::Wrapper *item) -> Diatom {
    Diatom d = diatomize(item->node->_getSD());
    d["minChildren"] = (double) item->node->childLimits().min;  // Todo: not do this?
    d["maxChildren"] = (double) item->node->childLimits().max;
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

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return NO;
}

-(std::map<std::string, std::string>&)descriptions {
  return nodeDescriptions;
}

@end

