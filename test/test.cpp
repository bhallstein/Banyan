//
// Test TreeDefinition serialization & deserialization.
//

#include "../GenericTree/Diatom/DiatomSerialization.h"
#include "../Banyan.h"
#include "register-test-nodes.h"
#include "_test.h"

#include <cstdio>
#include <fstream>
#include <streambuf>
#include <iostream>


std::string read_file(std::string filename) {
  std::ifstream file_stream(filename);
  return std::string(
    (std::istreambuf_iterator<char>(file_stream)),
    std::istreambuf_iterator<char>()
  );
}


Banyan::TreeDefinition load_tree(std::string filename) {
  Banyan::TreeDefinition bt;
  std::string file_str = read_file(filename);
  DiatomParseResult result = diatom__unserialize(file_str);
  if (result.success) {
    bt.fromDiatom(result.d);
  }
  return bt;
}


void testTreeDef() {
  p_file_header("Treedef-serialization.cpp");
  std::string file_str = read_file("trees/serialization.diatom");


  p_header("TreeDef serialization");
  DiatomParseResult result = diatom__unserialize(file_str);
  if (!result.success) {
    std::cout << result.error_string << "\n";
  }
  p_assert(result.success == true);

  Banyan::TreeDefinition bt;
  bt.fromDiatom(result.d);

  Diatom d = bt.toDiatom();
  std::string serialized = diatom__serialize(d);

  p_assert(file_str == serialized);
}


void testTreeInst() {
  p_file_header("TreeInstance.h");

  p_header("Repeater");
  {
    auto bt = load_tree("trees/repeater.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(MockLeaf::n_times_created == 6);
    p_assert(MockLeaf::n_times_called  == 6);
    p_assert(MockLeaf::n_times_resumed == 0);
  }


  p_header("Inverter");
  {
    auto bt = load_tree("trees/inverter.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(MockLeaf::n_times_created == 1);
    p_assert(MockLeaf::n_times_called  == 1);
    p_assert(MockLeaf::n_times_resumed == 0);
  }


  p_header("Succeeder");
  {
    auto bt = load_tree("trees/succeeder.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(MockLeaf::n_times_created == 2);
    p_assert(MockLeaf::n_times_called  == 2);
    p_assert(MockLeaf::n_times_resumed == 0);
  }


  p_header("Sequence");
  {
    auto bt = load_tree("trees/sequence.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(MockLeaf::n_times_created == 5);
    p_assert(MockLeaf::n_times_called  == 5);
    p_assert(MockLeaf::n_times_resumed == 0);
  }


  p_header("Selector");
  {
    auto bt = load_tree("trees/selector.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(MockLeaf::n_times_created == 4);
    p_assert(MockLeaf::n_times_called  == 4);
    p_assert(MockLeaf::n_times_resumed == 0);
  }


  p_header("Function nodes");
  {
    auto bt = load_tree("trees/function.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    _fn_node_calls = 0;
    _fn_node_calls_2 = 0;
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(_fn_node_calls == 4);
  }


  p_header("While");
  {
    auto bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    _fn_node_calls = 0;
    _fn_node_calls_2 = 0;
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(_fn_node_calls_2 == 3);
    p_assert(MockLeaf::n_times_created == 2);
  }
}


int main() {
  Banyan::TreeDefinition::registerBuiltins();
  testTreeDef();
  testTreeInst();
  return 0;
}

