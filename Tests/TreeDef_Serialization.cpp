/*

Test TreeDefinition serialization & deserialization.

*/

#include "Diatom-Storage.h"
#include "Banyan.h"
#include "_Register_Test_Nodes.h"

#include <cstdio>
#include <fstream>
#include <streambuf>

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


void testTreeDef();

int main() {
	testTreeDef();
	return 0;
}


void testTreeDef() {
	const char *filename = "trees/serialization_test.diatom";
	
	p_header("Testing TreeDef Serialization");
	Diatom d = diatomFromFile(filename);
		// Lua-backed version:
		//    Diatom d;
		//    d["treeDef"] = luaToDiatom(filename, "treeDef");
	
	Banyan::TreeDefinition bt;
	bt.fromDiatom(d);
	
	d = bt.toDiatom();
	std::string ser = diatomToString(d, "treeDef");
	// printf("%s\n", ser.c_str());
	
	std::ifstream file_stream(filename);
	std::string file_str(
		(std::istreambuf_iterator<char>(file_stream)),
		std::istreambuf_iterator<char>()
	);

	p_assert(file_str == ser);
	
	printf("\n");
}

