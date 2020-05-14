#include "NodeDefinition.h"

// std::vector<NodeDef::Wrapper> *NodeDef::definitions;

// Decorators
#include "Node_Repeater.h"
#include "Node_Inverter.h"
#include "Node_Succeeder.h"

NODE_DEFINITION(Repeater, Repeater::Def);
NODE_DEFINITION(Inverter, Inverter::Def);
NODE_DEFINITION(Succeeder, Succeeder::Def);
	// NODE_DEFINITION("Repeater", Repeater::Def); - fails due to dupl. identifier
	// NODE_DEFINITION("Geoff", Repeater::Def);    - fails due to dupl. symbol


// Composites
#include "Node_Sequence.h"
#include "Node_Selector.h"
#include "Node_While.h"

NODE_DEFINITION(Sequence, Sequence::Def);
NODE_DEFINITION(Selector, Selector::Def);
NODE_DEFINITION(While, While::Def);


// Other
#include "Node_MockLeaf.h"

NODE_DEFINITION(MockLeaf, MockLeaf::Def);

int MockLeaf::n_times_created;
int MockLeaf::n_times_called;
int MockLeaf::n_times_resumed;

// extern int _fn_node_calls;

