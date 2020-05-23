#include "../GenericTree/Diatom/DiatomSerialization.h"
#include "../Banyan.h"
#include "_test.h"

#include <cstdio>
#include <fstream>
#include <streambuf>
#include <iostream>


// Test nodes
// ------------------------------

int leaf__times_created = 0;
int leaf__times_called  = 0;
int leaf__times_resumed = 0;

class MockLeaf : public Banyan::NodeBase_CRTP<MockLeaf> {
public:
  Banyan::ChildLimits childLimits()  { return { 0, 0 }; }

  Diatomize::Descriptor getSD() {
    return {{
      diatomPart("succeeds", &succeeds)
    }};
  }

  MockLeaf()  { leaf__times_created += 1; }
  MockLeaf(const MockLeaf &m) : succeeds(m.succeeds) { leaf__times_created += 1; }
  ~MockLeaf() {  }

  static void reset() {
    leaf__times_created = 0;
    leaf__times_called  = 0;
    leaf__times_resumed = 0;
  }

  static void print() {
    printf("leaf__times_created: %d\n", leaf__times_created);
    printf("leaf__times_called : %d\n", leaf__times_called );
    printf("leaf__times_resumed: %d\n", leaf__times_resumed);
  }

  Banyan::NodeReturnStatus call(int identifier, int nChildren) {
    leaf__times_called += 1;
    return (Banyan::NodeReturnStatus) {
      (succeeds ? Banyan::NodeReturnStatus::Success : Banyan::NodeReturnStatus::Failure)
    };
  }
  Banyan::NodeReturnStatus resume(int identifier, Banyan::NodeReturnStatus &s) {
    // This should not be called, as we are a leaf node.
    _assert(false);
    leaf__times_resumed += 1;
    return s;
  }

  bool succeeds;  // Returns success or failure?
};

int fn_node_calls = 0;
int fn_node_calls_2 = 0;

Banyan::NodeReturnStatus node_fn(int identifier) {
  fn_node_calls++;
  return { Banyan::NodeReturnStatus::Success };
}

Banyan::NodeReturnStatus node_fn_fails_eventually(int id) {
  if (fn_node_calls_2++ == 2) {
    return { Banyan::NodeReturnStatus::Failure };
  }
  else {
    return { Banyan::NodeReturnStatus::Success };
  }
}

NODE_DEFINITION(MockLeaf, MockLeaf);
NODE_DEFINITION_FN(node_fn, FunctionTest);
NODE_DEFINITION_FN(node_fn_fails_eventually, NodeThatFailsEventually);


// Helpers
// ------------------------------

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


// Tests
// ------------------------------

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
    p_assert(leaf__times_created == 6);
    p_assert(leaf__times_called  == 6);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Inverter");
  {
    auto bt = load_tree("trees/inverter.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(leaf__times_created == 1);
    p_assert(leaf__times_called  == 1);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Succeeder");
  {
    auto bt = load_tree("trees/succeeder.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(leaf__times_created == 2);
    p_assert(leaf__times_called  == 2);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Sequence");
  {
    auto bt = load_tree("trees/sequence.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(leaf__times_created == 5);
    p_assert(leaf__times_called  == 5);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Selector");
  {
    auto bt = load_tree("trees/selector.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(leaf__times_created == 4);
    p_assert(leaf__times_called  == 4);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Function nodes");
  {
    auto bt = load_tree("trees/function.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    fn_node_calls = 0;
    fn_node_calls_2 = 0;
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(fn_node_calls == 4);
  }


  p_header("While");
  {
    auto bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    fn_node_calls = 0;
    fn_node_calls_2 = 0;
    bt_inst.begin();

    p_assert(bt_inst.stackSize() == 0);
    p_assert(fn_node_calls_2 == 3);
    p_assert(leaf__times_created == 2);
  }
}


int main() {
  Banyan::TreeDefinition::registerBuiltins();
  testTreeDef();
  testTreeInst();
  return 0;
}

