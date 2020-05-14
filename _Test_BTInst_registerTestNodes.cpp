#include "_Test_BTInst_registerTestNodes.h"


// Register mock leaf for testing
NODE_DEFINITION(MockLeaf, MockLeaf::Def);

int MockLeaf::n_times_created;
int MockLeaf::n_times_called;
int MockLeaf::n_times_resumed;


// Register function node for testing
int _fn_node_calls = 0;
Banyan::BehaviourStatus someNodeFunction(int identifier, int n_children) {
	_fn_node_calls++;
	return { Banyan::NodeReturnStatus::Success };
}
int _fn_node_calls_2 = 0;
Banyan::BehaviourStatus nodeFnThatFailsEventually(int id, int nch) {
	if (++_fn_node_calls_2 == 3) {
		printf("nodeFnThatFailsEventually: Failure\n");
		return { Banyan::NodeReturnStatus::Failure };
	}
	else {
		printf("nodeFnThatFailsEventually: Success\n");
		return { Banyan::NodeReturnStatus::Success };
	}
}
NODE_DEFINITION_FN(FunctionTest, someNodeFunction);
NODE_DEFINITION_FN(NodeThatFailsEventually, nodeFnThatFailsEventually);
