/*

Test TreeInstance -- pushing & popping etc.

*/

#include "Banyan.h"
#include "_Register_Test_Nodes.h"
#include "Diatom-Storage.h"

#define p_assert(x) do {             \
		printf("TEST: %35s", #x);    \
		assert(x);                   \
		printf(" - PASS :)\n");      \
	} while (false)
#define p_header(s) do {                                  \
		for (int i=0; s[i] != '\0'; ++i) printf("*");     \
		printf("********\n");                             \
		printf("**  %s  **\n", s);                        \
		for (int i=0; s[i] != '\0'; ++i) printf("*");     \
		printf("********\n");                             \
	} while (false)


void testTreeInst();

int main() {
	testTreeInst();
	return 0;
}


void loadTreeDef(const std::string &fn, Banyan::TreeDefinition &bt) {
	bt.reset();
	
	Diatom d = diatomFromFile(fn);
	bt.fromDiatom(d);
}


void testTreeInst() {
	
	Banyan::TreeDefinition bt;
	
	/**********************/
	/*** Test Repeaters ***/
	/**********************/
	
	p_header("Testing Repeaters");
	loadTreeDef("trees/repeater_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		MockLeaf::reset();
		bt_inst.begin();
	
		p_assert(bt_inst.stackSize() == 0);
		p_assert(MockLeaf::n_times_created == 6);
		p_assert(MockLeaf::n_times_called  == 6);
		p_assert(MockLeaf::n_times_resumed == 0);
		printf("\n");
	}
	
	/**********************/
	/*** Test Inverters ***/
	/**********************/
	
	p_header("Testing Inverters");
	loadTreeDef("trees/inverter_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		MockLeaf::reset();
		bt_inst.begin();

		p_assert(bt_inst.stackSize() == 0);
		p_assert(MockLeaf::n_times_created == 1);
		p_assert(MockLeaf::n_times_called  == 1);
		p_assert(MockLeaf::n_times_resumed == 0);
		printf("\n");
	}


	/***********************/
	/*** Test Succeeders ***/
	/***********************/

	p_header("Testing Succeeders");
	loadTreeDef("trees/succeeder_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		MockLeaf::reset();
		bt_inst.begin();

		p_assert(bt_inst.stackSize() == 0);
		p_assert(MockLeaf::n_times_created == 2);
		p_assert(MockLeaf::n_times_called  == 2);
		p_assert(MockLeaf::n_times_resumed == 0);
		printf("\n");
	}

	/**********************/
	/*** Test Sequences ***/
	/**********************/

	p_header("Testing Sequences");
	loadTreeDef("trees/sequence_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		MockLeaf::reset();
		bt_inst.begin();

		p_assert(bt_inst.stackSize() == 0);
		p_assert(MockLeaf::n_times_created == 5);
		p_assert(MockLeaf::n_times_called  == 5);
		p_assert(MockLeaf::n_times_resumed == 0);
		printf("\n");
	}


	/**********************/
	/*** Test Selectors ***/
	/**********************/

	p_header("Testing Selectors");
	loadTreeDef("trees/selector_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);

		MockLeaf::reset();
		bt_inst.begin();
		// printf("n_times_created: %d\n", MockLeaf::n_times_created);

		p_assert(bt_inst.stackSize() == 0);
		p_assert(MockLeaf::n_times_created == 4);
		p_assert(MockLeaf::n_times_called  == 4);
		p_assert(MockLeaf::n_times_resumed == 0);
		printf("\n");
	}


	/**********************/
	/*** Test Functions ***/
	/**********************/

	p_header("Testing Functions");
	loadTreeDef("trees/function_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		_fn_node_calls = 0;
		_fn_node_calls_2 = 0;
		bt_inst.begin();

		p_assert(bt_inst.stackSize() == 0);
		p_assert(_fn_node_calls == 4);
		printf("\n");
	}


	/*******************/
	/*** Test Whiles ***/
	/*******************/

	p_header("Testing Whiles");
	loadTreeDef("trees/while_test.diatom", bt);
	{
		Banyan::TreeInstance bt_inst(&bt, 1);
		MockLeaf::reset();
		_fn_node_calls = 0;
		_fn_node_calls_2 = 0;
		bt_inst.begin();

		p_assert(bt_inst.stackSize() == 0);
		p_assert(_fn_node_calls_2 == 3);
		p_assert(MockLeaf::n_times_created == 2);
		printf("\n");
	}
}

