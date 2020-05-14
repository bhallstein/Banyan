/*

Test BT_Inst pushing & popping etc.

*/

#include "Banyan.h"
#include "Node_Repeater.h"
#include "Node_Inverter.h"
#include "_Test_BTInst_registerTestNodes.h"

#define p_assert(x) do {        \
		printf("TEST: %35s", #x);    \
		assert(x);              \
		printf(" - PASS :)\n"); \
	} while (false)


int main() {
	
	/**********************/
	/*** Test Repeaters ***/
	/**********************/
	
	MockLeaf::reset();
	
	Banyan::TreeDefinition bt_def("tree_repeater_test.lua");
	Banyan::TreeInstance bt_inst(&bt_def, 1);
	
	bt_inst.begin();
	
	printf("\nTesting repeaters:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 6);
	p_assert(MockLeaf::n_times_called  == 6);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Inverters ***/
	/**********************/
	
	MockLeaf::reset();
	
	bt_def = Banyan::TreeDefinition("tree_inverter_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting inverters:\n");
	p_assert(bt_inst.stackSize() == 0);	
	p_assert(MockLeaf::n_times_created == 1);
	p_assert(MockLeaf::n_times_called  == 1);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/***********************/
	/*** Test Succeeders ***/
	/***********************/
	
	MockLeaf::reset();
	
	bt_def = Banyan::TreeDefinition("tree_succeeder_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting succeeders:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 2);
	p_assert(MockLeaf::n_times_called  == 2);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Sequences ***/
	/**********************/
	
	MockLeaf::reset();
	
	bt_def = Banyan::TreeDefinition("tree_sequence_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting sequences:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(MockLeaf::n_times_created == 5);
	p_assert(MockLeaf::n_times_called  == 5);
	p_assert(MockLeaf::n_times_resumed == 0);
	
	
	/**********************/
	/*** Test Selectors ***/
	/**********************/
	
	MockLeaf::reset();
	
	bt_def = Banyan::TreeDefinition("tree_selector_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
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
	
	bt_def = Banyan::TreeDefinition("tree_function_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting functions:\n");
	
	p_assert(bt_inst.stackSize() == 0);
	p_assert(_fn_node_calls == 4);
	
	
	/*******************/
	/*** Test Whiles ***/
	/*******************/
	
	MockLeaf::reset();
	
	bt_def = Banyan::TreeDefinition("tree_while_test.lua");
	bt_inst = Banyan::TreeInstance(&bt_def, 1);
	
	bt_inst.begin();

	printf("\nTesting whiles:\n");
	p_assert(bt_inst.stackSize() == 0);
	p_assert(_fn_node_calls_2 == 3);
	p_assert(MockLeaf::n_times_created == 2);

	
	return 0;
}


