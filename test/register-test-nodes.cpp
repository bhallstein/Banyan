#include "register-test-nodes.h"

// Register mock leaf for testing
NODE_DEFINITION(MockLeaf, MockLeaf);

int MockLeaf::n_times_created;
int MockLeaf::n_times_called;
int MockLeaf::n_times_resumed;

int _fn_node_calls = 0;
Banyan::NodeReturnStatus someNodeFunction(int identifier) {
	_fn_node_calls++;
	return { Banyan::NodeReturnStatus::Success };
}
int _fn_node_calls_2 = 0;
Banyan::NodeReturnStatus nodeFnThatFailsEventually(int id) {
	if (_fn_node_calls_2++ == 2) {
		// printf("nodeFnThatFailsEventually: Failure\n");
		return { Banyan::NodeReturnStatus::Failure };
	}
	else {
		// printf("nodeFnThatFailsEventually: Success\n");
		return { Banyan::NodeReturnStatus::Success };
	}
}
NODE_DEFINITION_FN(someNodeFunction, FunctionTest);
NODE_DEFINITION_FN(nodeFnThatFailsEventually, NodeThatFailsEventually);
