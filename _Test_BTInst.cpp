/*

Test BT_Inst pushing & popping etc.

*/

#include "BT_Inst.h"
#include "BT_Def.h"
#include "Node_Repeater.h"
#include "Node_Inverter.h"
#include "Node_MockLeaf.h"

#define p_assert(x) do {        \
		printf("TEST: %35s", #x);    \
		assert(x);              \
		printf(" - PASS :)\n"); \
	} while (0)

void resetMockLeaf() {
	MockLeaf::n_times_created = 0;
	MockLeaf::n_times_called  = 0;
	MockLeaf::n_times_resumed = 0;
}

// Register mock leaf for testing
#include "Node_MockLeaf.h"

NODE_DEFINITION(MockLeaf, MockLeaf::Def);

int MockLeaf::n_times_created;
int MockLeaf::n_times_called;
int MockLeaf::n_times_resumed;

// Register function node for testing
int _fn_node_calls = 0;
BehaviourStatus someNodeFunction(int identifier, int n_children) {
	_fn_node_calls++;
	return { NodeReturnStatus::Success };
}
int _fn_node_calls_2 = 0;
BehaviourStatus nodeFnThatFailsEventually(int id, int nch) {
	if (++_fn_node_calls_2 == 3) {
		printf("nodeFnThatFailsEventually: Failure\n");
		return { NodeReturnStatus::Failure };
	}
	else {
		printf("nodeFnThatFailsEventually: Success\n");
		return { NodeReturnStatus::Success };
	}
}
NODE_DEFINITION_FN(FunctionTest, someNodeFunction);
NODE_DEFINITION_FN(NodeThatFailsEventually, nodeFnThatFailsEventually);

int main() {
	
	/**********************/
	/*** Test Repeaters ***/
	/**********************/
	
	resetMockLeaf();
	
	BT_Def  bt_def("tree_repeater_test.lua");
	BT_Inst bt_inst(&bt_def, 1);
	
	bt_inst.begin();
	
	printf("\nTesting repeaters:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 6);
	p_assert(MockLeaf::n_times_called  == 6);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Inverters ***/
	/**********************/
	
	resetMockLeaf();
	
	bt_def = BT_Def("tree_inverter_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting inverters:\n");
	p_assert(bt_inst.stackSize() == 0);	
	p_assert(MockLeaf::n_times_created == 1);
	p_assert(MockLeaf::n_times_called  == 1);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/***********************/
	/*** Test Succeeders ***/
	/***********************/
	
	resetMockLeaf();
	
	bt_def = BT_Def("tree_succeeder_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting succeeders:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 2);
	p_assert(MockLeaf::n_times_called  == 2);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Sequences ***/
	/**********************/
	
	resetMockLeaf();
	
	bt_def = BT_Def("tree_sequence_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting sequences:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 5);
	p_assert(MockLeaf::n_times_called  == 5);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Selectors ***/
	/**********************/
	
	resetMockLeaf();
	
	bt_def = BT_Def("tree_selector_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting selectors:\n");
	printf("n_times_created: %d\n", MockLeaf::n_times_created);
	
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 4);
	p_assert(MockLeaf::n_times_called  == 4);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Functions ***/
	/**********************/
	
	bt_def = BT_Def("tree_function_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting functions:\n");
	
	p_assert(bt_inst.stackSize() == 0);
	p_assert(_fn_node_calls == 4);
	
	
	/*******************/
	/*** Test Whiles ***/
	/*******************/
	
	resetMockLeaf();
	
	bt_def = BT_Def("tree_while_test.lua");
	bt_inst = BT_Inst(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting whiles:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(_fn_node_calls_2 == 3);
	p_assert(MockLeaf::n_times_created == 2);

	
	return 0;
}


