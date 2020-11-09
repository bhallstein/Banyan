#include "../GenericTree/Diatom/DiatomSerialization.h"
#include "../Banyan.h"
#include "_test.h"

#include <cstdio>
#include <fstream>
#include <streambuf>
#include <iostream>


int leaf__times_created = 0;
int leaf__times_called  = 0;
int leaf__times_resumed = 0;
Banyan::TreeInstance *global_tree_instance;


// MockLeaf
// ------------------------------

class MockLeaf : public Banyan::Node<MockLeaf> {
public:
  std::string type() { return "MockLeaf"; }
  Banyan::ChildLimits childLimits()  { return { 0, 0 }; }


  bool succeeds;


  Diatom to_diatom() {
    Diatom d;
    d["succeeds"] = succeeds;
    return d;
  }
  void from_diatom(Diatom d) {
    succeeds = d["succeeds"].value__bool;
  }


  MockLeaf() { leaf__times_created += 1; }
  MockLeaf(const MockLeaf &m) : succeeds(m.succeeds) { leaf__times_created += 1; }
  ~MockLeaf() {  }


  Banyan::NodeReturnStatus activate(int identifier, int nChildren) {
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


  static void reset() {
    leaf__times_created = 0;
    leaf__times_called  = 0;
    leaf__times_resumed = 0;
  }
};

NodeDefinition(MockLeaf);



// node functions
// ------------------------------

int calls__mock__succeeder = 0;
int calls__mock__fails_on_third_call = 0;

Banyan::NodeReturnStatus mock__succeeder(size_t identifier) {
  calls__mock__succeeder++;
  return { Banyan::NodeReturnStatus::Success };
}

Banyan::NodeReturnStatus mock__fails_on_third_call(size_t id) {
  if (calls__mock__fails_on_third_call++ == 2) {
    return { Banyan::NodeReturnStatus::Failure };
  }
  else {
    return { Banyan::NodeReturnStatus::Success };
  }
}

Banyan::NodeReturnStatus mock__set_state(size_t id) {
  global_tree_instance->set_state_object("AStateItem", 1);
  global_tree_instance->set_state_object("AnotherStateItem", 2);
  global_tree_instance->set_state_object("Z", 3);
  return { Banyan::NodeReturnStatus::Running };
}

Banyan::NodeReturnStatus mock__running(size_t id) {
  return { Banyan::NodeReturnStatus::Running };
}

NodeDefinitionFunction(mock__succeeder, MockSucceeder);
NodeDefinitionFunction(mock__fails_on_third_call, MockFailsOnThirdCall);
NodeDefinitionFunction(mock__set_state, MockSetState);
NodeDefinitionFunction(mock__running, MockRunning);



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


// NodeRegistry tests
// ------------------------------

void test__node_registry() {
  p_file_header("NodeRegistry");

  p_header("Autoregister");
  {
    size_t n_definitions = Banyan::NodeRegistry::definitions().size();
    p_assert(n_definitions == 11);
      // 6 builtins, MockLeaf, 4 functional nodes
  }

  p_header("getNode");
  {
    Banyan::NodeSuper *def__repeater = Banyan::NodeRegistry::getNode("Repeater");
    p_assert(def__repeater->type() == "Repeater");

    Banyan::NodeSuper *def__mock_leaf = Banyan::NodeRegistry::getNode("MockLeaf");
    p_assert(def__mock_leaf->type() == "MockLeaf");

    Banyan::NodeSuper *def__mock_succeeder = Banyan::NodeRegistry::getNode("MockSucceeder");
    p_assert(def__mock_succeeder->type() == "MockSucceeder");

    Banyan::NodeSuper *def__nonexistent = Banyan::NodeRegistry::getNode("Nonexistent");
    p_assert(def__nonexistent == NULL);
  }

  p_header("ensureNotAlreadyInDefinitions");
  {
    int throws = 0;
    Banyan::NodeRegistry::ensureNotAlreadyInDefinitions("NotInDefinitions");
    p_assert(throws == 0);

    try {
      Banyan::NodeRegistry::ensureNotAlreadyInDefinitions("MockLeaf");
    }
    catch(std::runtime_error exc) {
      throws += 1;
    }
    p_assert(throws == 1);
  }
}


// TreeDefinition tests
// ------------------------------

void test__tree_definition() {
  p_file_header("TreeDefinition");
  p_header("TreeDef serialization");

  std::string file_str = read_file("trees/serialization.diatom");
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



// TreeInstance tests
// ------------------------------

void test__tree_instance() {
  p_file_header("TreeInstance");

  p_header("Repeater");
  {
    Banyan::TreeDefinition bt = load_tree("trees/repeater.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(leaf__times_created == 6);
    p_assert(leaf__times_called  == 6);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Inverter");
  {
    Banyan::TreeDefinition bt = load_tree("trees/inverter.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(leaf__times_created == 1);
    p_assert(leaf__times_called  == 1);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Succeeder");
  {
    Banyan::TreeDefinition bt = load_tree("trees/succeeder.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(leaf__times_created == 2);
    p_assert(leaf__times_called  == 2);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Sequence");
  {
    Banyan::TreeDefinition bt = load_tree("trees/sequence.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(leaf__times_created == 5);
    p_assert(leaf__times_called  == 5);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Selector");
  {
    Banyan::TreeDefinition bt = load_tree("trees/selector.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    MockLeaf::reset();
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(leaf__times_created == 4);
    p_assert(leaf__times_called  == 4);
    p_assert(leaf__times_resumed == 0);
  }


  p_header("Function nodes");
  {
    Banyan::TreeDefinition bt = load_tree("trees/function.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    calls__mock__succeeder = 0;
    calls__mock__fails_on_third_call = 0;
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(calls__mock__succeeder == 4);
  }


  p_header("While");
  {
    Banyan::TreeDefinition bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    MockLeaf::reset();
    calls__mock__succeeder = 0;
    calls__mock__fails_on_third_call = 0;
    bt_inst.begin();

    p_assert(bt_inst.node_stack.size() == 0);
    p_assert(calls__mock__fails_on_third_call == 3);
    p_assert(leaf__times_created == 2);
  }

  p_header("set_state_object");
  {
    Banyan::TreeDefinition bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    p_assert(bt_inst.state.size() == 0);
    bt_inst.set_state_object("XYZ", 4);
    p_assert(bt_inst.state.size() == 1);
  }

  p_header("get_state_object");
  {
    Banyan::TreeDefinition bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    bt_inst.set_state_object("XYZ", 4);
    Banyan::StateObject obj = bt_inst.get_state_object("XYZ");
    p_assert(obj.type == Banyan::StateObject::Int);
    p_assert(obj.value__int == 4);

    Banyan::StateObject null_obj = bt_inst.get_state_object("ABC");
    p_assert(null_obj.type == Banyan::StateObject::Null);
  }

  p_header("remove_state_object");
  {
    Banyan::TreeDefinition bt = load_tree("trees/while.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);

    bt_inst.set_state_object("XYZ", 4);
    p_assert(bt_inst.state.size() == 1);
    bt_inst.remove_state_object("XYZ");
    p_assert(bt_inst.state.size() == 0);
  }

  p_header("popNode() removes state contexts");
  {
    Banyan::TreeDefinition bt = load_tree("trees/state.diatom");
    Banyan::TreeInstance bt_inst(&bt, 1);
    global_tree_instance = &bt_inst;

    bt_inst.begin();
    p_assert(bt_inst.state.size() == 3);
    bt_inst.end_running_node({ Banyan::NodeReturnStatus::Success });
    p_assert(bt_inst.state.size() == 1);
    Banyan::StateObject state__a = bt_inst.get_state_object("Z");
    p_assert(state__a.value__int == 3);
  }
}


int main() {
  Banyan::TreeDefinition::registerBuiltins();
  test__node_registry();
  test__tree_definition();
  test__tree_instance();

  return 0;
}

