#pragma once
#include <iostream>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

namespace Banyan {


// Map
// ------------------------------------
// - compiles faster than std::map and in testing provides marginally
//   better performance (!)

template <class T>
struct Map {
  struct Entry {
    std::string name;
    T           item;
  };

  std::vector<Entry> entries;

  Map() {}
  Map(std::initializer_list<Entry> e) : entries(e) {}

  T& operator[](std::string name) {
    for (auto& entry : entries) {
      if (entry.name == name) {
        return entry.item;
      }
    }

    entries.push_back({name});
    return entries.back().item;
  }

  const T* get(std::string name) const {
    for (const auto& entry : entries) {
      if (entry.name == name) {
        return &entry.item;
      }
    }
    return 0;
  }
};


// Definitions
// ------------------------------------

enum ReturnStatus {
  Running = 1,
  Succeeded,
  Failed,
  PushChild,
  BeginTree,
};

struct Ret {
  ReturnStatus status;
  int          child;
};

struct Prop {
  union {
    bool  bool_value;
    int   int_value;
    float float_value;
  };
  std::string string_value;
};


// Random number helpers
// ------------------------------------

inline std::mt19937* get_mersenne_twister() {
  static std::mt19937* mt = 0;

  if (!mt) {
    std::random_device rd;
    mt = new std::mt19937(rd());
  }

  return mt;
}

inline int random_int_up_to(int max) {
  std::uniform_int_distribution<> distrib(0, max);
  return distrib(*get_mersenne_twister());
}

template <class T>
inline void scramble(T& v) {
  std::mt19937* g = get_mersenne_twister();
  std::shuffle(v.begin(), v.end(), g);
}


// Node, RunNode, NodeType
// ------------------------------------

class NodeType;

struct Node {
  const NodeType*   node_type;
  Map<Prop>         props;  // Props for this node in the tree (default + overridden)
  std::vector<Node> children;
};

struct RunNode {
  Node*     tree_node;
  Map<Prop> props;  // Copy of props to operate on
};

using NodeChildren  = std::vector<Node>;
using activate_func = Ret(RunNode& node, size_t identifier);
using resume_func   = Ret(RunNode& node, size_t identifier, ReturnStatus status);

inline Ret default_activate_func(RunNode&, size_t) { return Ret{Succeeded}; }
inline Ret default_resume_func(RunNode&, size_t, ReturnStatus) { return Ret{Succeeded}; }

struct NodeType {
  std::string    name;
  activate_func* activate      = default_activate_func;
  resume_func*   resume        = default_resume_func;
  int            min_children  = 0;
  int            max_children  = 0;
  Map<Prop>      default_props = {};
};

inline void check_node_children(const NodeType& node_type, size_t n_children) {
  bool ok = n_children >= node_type.min_children &&
            (node_type.max_children == -1 || n_children <= node_type.max_children);
  if (!ok) {
    throw std::runtime_error("banyan: node has invalid number of children");
  }
}

inline Node mk_node(const NodeType& node_type, const Map<Prop>& with_props = {}, const NodeChildren& children = {}) {
  const Map<Prop>& default_props = node_type.default_props;
#ifdef BanyanCheckChildren
  check_node_children(node_type, children.size());
#endif

  Node node{
    &node_type,
    default_props,
    children,
  };

  for (const auto& entry : with_props.entries) {  // Copy props as spcfd for this node in tree
    node.props[entry.name] = entry.item;
  }
  return node;
}

inline RunNode mk_run_node(Node& node) {
  return RunNode{&node, node.props};
}

inline Ret activate_node(RunNode& rn, size_t identifier) {
  return rn.tree_node->node_type->activate(rn, identifier);
}

inline Ret resume_node(RunNode& rn, size_t identifier, ReturnStatus status) {
  return rn.tree_node->node_type->resume(rn, identifier, status);
}


// Instance -- a running behaviour tree instance
// ------------------------------------

struct Instance {
  Node*                tree;
  size_t               identifier;
  std::vector<RunNode> stack;
};

inline bool instance_finished(Instance& inst) {
  return inst.stack.size() == 0;
}

void instance_update(Instance& inst, Ret ret) {
  while (!instance_finished(inst) && ret.status != Running) {
    if (ret.status == Succeeded || ret.status == Failed) {
      inst.stack.pop_back();
      if (instance_finished(inst)) {
        break;
      }
      ret = resume_node(inst.stack.back(), inst.identifier, ret.status);
    }

    else if (ret.status == PushChild) {
      RunNode& rn = inst.stack.back();
      if (ret.child >= rn.tree_node->children.size()) {
        throw std::runtime_error("banyan: pushed child is out of bounds");
      }
      inst.stack.push_back(mk_run_node(rn.tree_node->children[ret.child]));
      ret = activate_node(inst.stack.back(), inst.identifier);
    }
  }
}

inline void instance_begin(Instance& inst) {
  inst.stack.push_back(mk_run_node(*inst.tree));
  Ret ret = activate_node(inst.stack.back(), inst.identifier);
  instance_update(inst, ret);
}


// Inverter
// ------------------------------------

inline Ret activate_push_first(RunNode& rn, size_t identifier) {
  return Ret{PushChild, 0};
}

inline Ret inverter_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  return Ret{status == Failed ? Succeeded : Failed};
}

inline Node Inverter(const NodeChildren& children) {
  static NodeType InverterType{
    "Inverter",
    activate_push_first,
    inverter_resume,
    1,
    1,
  };
  return mk_node(InverterType, {}, children);
}


// Repeater
// ------------------------------------

#define RepeatForever 0

inline Ret repeater_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  if (status == Failed && rn.props["break_on_failure"].bool_value) {
    return Ret{Failed};
  }

  Prop& n = rn.props["n"];
  Prop& i = rn.props["i"];
  if (n.int_value == 0) {
    return Ret{PushChild, 0};
  }

  i.int_value += 1;
  if (n.int_value == RepeatForever || i.int_value < n.int_value) {
    return Ret{PushChild, 0};
  }

  return Ret{Succeeded};
}

inline Node Repeater(const Map<Prop>& props, const NodeChildren& children) {
  static NodeType RepeaterType{
    "Repeater",
    activate_push_first,
    repeater_resume,
    1,
    1,
    {
      {"n", {.int_value = 1}},
      {"break_on_failure", {.bool_value = false}},
    },
  };
  return mk_node(RepeaterType, props, children);
};


// Selector
// ------------------------------------

#define SelectRandom -1

inline Ret selector_activate(RunNode& rn, size_t identifier) {
  std::cout << "selector_activate\n";
  int i = rn.props["i"].int_value;
  if (i == SelectRandom) {
    i = random_int_up_to(rn.tree_node->children.size() - 1);
  }
  std::cout << "Selected " << i << " (i prop: " << rn.props["i"].int_value << ")\n";
  return Ret{PushChild, i};
}

inline Ret selector_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  return Ret{status};
}

inline Node Selector(const Map<Prop>& props, const NodeChildren& children) {
  static NodeType SelectorType{
    "Selector",
    selector_activate,
    selector_resume,
    1,
    -1,
    {
      {"i", {.int_value = SelectRandom}},
    },
  };
  return mk_node(SelectorType, props, children);
}


// Sequence
// ------------------------------------

inline Ret sequence_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  if (status == Failed && rn.props["break_on_failure"].bool_value) {
    return Ret{Failed};
  }

  Prop& i = rn.props["i"];
  if (i.int_value < rn.tree_node->children.size() - 1) {
    i.int_value += 1;
    return Ret{PushChild, i.int_value};
  }

  return Ret{Succeeded};
}

inline Node Sequence(const Map<Prop>& props, const NodeChildren& children) {
  static NodeType SequenceType{
    "Sequence",
    activate_push_first,
    sequence_resume,
    1,
    -1,
    {
      {"i", {.int_value = 0}},
      {"break_on_failure", {.bool_value = false}},
    },
  };
  return mk_node(SequenceType, props, children);
}


// Succeeder
// ------------------------------------

inline Ret succeeder_activate(RunNode& rn, size_t identifier) {
  return rn.tree_node->children.size() == 0
           ? Ret{Succeeded}
           : Ret{PushChild, 0};
}

inline Ret succeeder_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  return Ret{Succeeded};
}

const Node Succeeder(const NodeChildren& children = {}) {
  static NodeType SucceederType{
    "Succeeder",
    succeeder_activate,
    succeeder_resume,
    0,
    1,
  };
  return mk_node(SucceederType, {}, children);
}


// While
// ------------------------------------

inline Ret while_resume(RunNode& rn, size_t identifier, ReturnStatus status) {
  Prop& i = rn.props["i"];
  // Resume after first child
  if (i.int_value == 0) {
    if (status == Succeeded) {
      i.int_value += 1;
      return Ret{PushChild, 1};
    }
    else {
      return Ret{Succeeded};
    }
  }
  // After second child
  else {
    i.int_value = 0;
    return Ret{PushChild, 0};
  }
}

inline Node While(const NodeChildren& children) {
  static NodeType WhileType{
    "While",
    activate_push_first,
    while_resume,
    2,
    2,
    {{"i", {.int_value = 0}}},
  };
  return mk_node(WhileType, {}, children);
}


}  // namespace Banyan
