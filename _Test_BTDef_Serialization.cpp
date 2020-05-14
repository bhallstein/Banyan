/*

Test tree serialization:
 - write out an array of all nodes found in the tree
 - write out a tree using indices from the array

*/


#include "BT_Def.h"
#include <cstdio>
#include "Node_MockLeaf.h"
#include <iostream>

#include <string>
#include <fstream>
#include <streambuf>

#define p_assert(x) do {        \
		printf("TEST: %35s", #x);    \
		assert(x);              \
		printf(" - PASS :)\n"); \
	} while (false)

NODE_DEFINITION(MockLeaf, MockLeaf::Def);

int MockLeaf::n_times_created;
int MockLeaf::n_times_called;
int MockLeaf::n_times_resumed;

int main() {
	
	const char *filename = "tree_serialization_test.lua";
	
	BT_Def bt(filename);
	
	std::string bt_serialized = bt.serialize();

	std::ifstream file_stream(filename);
	std::string file_str(
		(std::istreambuf_iterator<char>(file_stream)),
		std::istreambuf_iterator<char>()
	);
	
	p_assert(file_str == bt_serialized);
	
	return 0;
}

