/*

Test tree serialization:
 - write out an array of all nodes found in the tree
 - write out a tree using indices from the array

*/


#include "NodeDefinition.h"
#include <cstdio>
#include "Node_Repeater.h"
#include "BT_Def.h"


int main() {
	
	// Deserializing a BT_Def from a lua file
	BT_Def bt("tree_repeater_test.lua");
	
	// Serialize again
	printf("%s", bt.serialize().c_str());
	
	return 0;
}

