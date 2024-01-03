#ifndef Banyan_h
#define Banyan_h

#include <random>
#include <stdexcept>
#include <string>
#include <vector>

#include "map.hpp"

namespace Banyan {


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

template <class T>
void scramble(std::vector<T>& v) {
  std::random_device rd;
  std::mt19937       g(rd());
  std::shuffle(v.begin(), v.end(), g);
}


// RunNode
// ------------------------------------

struct Node {
  struct RunNode {  // Copy of node without children used when running tree
    Node*     node;
    Map<Prop> props;
    RunNode(Node* n) : node(n), props(n->props) {}

    Ret activate(size_t identifier) {
      return node->activate(identifier, *this);
    }
    Ret resume(size_t identifier, ReturnStatus status) {
      return node->resume(identifier, *this, status);
    }
  };

  int       min_children = 0;
  int       max_children = 0;  // If -1, no maximum
  Map<Prop> props;

  typedef std::function<Ret(size_t, RunNode&)>               activate_func;
  typedef std::function<Ret(size_t, RunNode&, ReturnStatus)> resume_func;

  activate_func activate = [](size_t identifier, RunNode&) {
    return Ret{Succeeded};
  };
  resume_func resume = [](size_t identifier, RunNode&, ReturnStatus) {
    return Ret{Succeeded};
  };

  std::vector<Node> children;
};

typedef Map<Prop>         NodeProps;
typedef std::vector<Node> NodeChildren;


// Instance -- a running behaviour tree instance
// ------------------------------------

struct Instance {
  Node*                      tree;
  size_t                     identifier;
  std::vector<Node::RunNode> stack;

  Instance(Node* _tree, size_t _identifier) : tree(_tree), identifier(_identifier) {}

  bool finished() {
    return stack.size() == 0;
  }

  void begin() {
    stack.push_back(tree);
    Ret ret = stack.back().activate(identifier);
    update(ret);
  }

  void update(Ret ret) {
    while (!finished() && ret.status != Running) {
      if (ret.status == Succeeded || ret.status == Failed) {
        stack.pop_back();
        if (finished()) {
          break;
        }
        Node::RunNode& rn = stack.back();
        ret               = rn.resume(identifier, ret.status);
      }

      else if (ret.status == PushChild) {
        stack.push_back(Node::RunNode(&stack.back().node->children[ret.child]));
        ret = stack.back().activate(identifier);
      }
    }
  }
};


// initialize_node() - called by node constructors to assign children
// ------------------------------------

inline void check_children_valid(Node& node, const NodeChildren& children) {
  auto n_children    = children.size();
  bool n_children_ok = n_children >= node.min_children &&
                       (node.max_children == -1 || n_children <= node.max_children);
  if (!n_children_ok) {
    throw std::runtime_error("Error: node has invalid number of children");
  }
}

inline Node& initialize_node(Node& node, const NodeChildren& children) {
  check_children_valid(node, children);
  node.children = children;
  return node;
}


// Inverter
// ------------------------------------

inline Node Inverter(NodeChildren children) {
  Node inverter = {
    .min_children = 1,
    .max_children = 1,
    .activate     = [](size_t, auto& n) { return Ret{PushChild, 0}; },
    .resume       = [](size_t, auto& n, ReturnStatus s) {
        ReturnStatus status = s == Failed ? Succeeded : Failed;
        return Ret{.status = status}; },
  };
  return initialize_node(inverter, children);
}


// Repeater
// ------------------------------------

typedef int      RepeaterN;
typedef bool     RepeaterBreakOnFailure;
inline RepeaterN RepeaterForever() { return 0; }

inline Node Repeater(RepeaterN N, RepeaterBreakOnFailure break_on_failure, NodeChildren children) {
  Node repeater = {
    .min_children = 1,
    .max_children = 1,
    .props        = {
      {"i", {.int_value = 0}},
      {"N", {.int_value = N}},
      {"break_on_failure", {.bool_value = break_on_failure}},
    },
    .activate = [](size_t, auto& n) { return Ret{PushChild, 0}; },
    .resume   = [](size_t, auto& n, ReturnStatus s) {
        if (s == Failed && n.props["break_on_failure"].bool_value) {
          return Ret{Failed};
        }

        if (n.props["N"].int_value == 0) {
          return Ret{PushChild, 0};
        }

        int& N = n.props["N"].int_value;
        int& i = n.props["i"].int_value;
        i += 1;

        if (N == RepeaterForever() || i < N) {
          return Ret{PushChild, 0};
        }

        return Ret{Succeeded}; },
  };
  return initialize_node(repeater, children);
}


// Selector
// ------------------------------------

typedef bool SelectorBreakOn1stSuccess;
typedef bool SelectorRandomizeOrder;

inline Node Selector(SelectorBreakOn1stSuccess break_on_1st_success, SelectorRandomizeOrder randomize_order, NodeChildren children) {
  Node selector = {
    .min_children = 1,
    .max_children = -1,
    .props        = {
      {"i", {.int_value = 0}},
      {"break_on_1st_success", {.bool_value = break_on_1st_success}},
      {"randomize_order", {.bool_value = randomize_order}},
    },
    .activate = [](size_t, auto& n) {
        if (n.props["randomize_order"].bool_value) {
          scramble(n.node->children);  // TODO: fix
        }

        return Ret{PushChild, 0}; },
    .resume   = [](size_t, auto& n, ReturnStatus s) -> Ret {
      if (s == Succeeded && n.props["break_on_1st_success"].bool_value) {
        return {Succeeded};
      }

      int& i = n.props["i"].int_value;
      if (i < n.node->children.size() - 1) {
        i += 1;
        return Ret{PushChild, i};
      }

      return Ret{s};
    },
  };
  return initialize_node(selector, children);
}


// Sequence
// ------------------------------------

typedef bool SequenceBreakOnFailure;

inline Node Sequence(SequenceBreakOnFailure break_on_failure, NodeChildren children) {
  Node sequence = {
    .min_children = 1,
    .max_children = -1,
    .props        = {
      {"i", {.int_value = 0}},
      {"break_on_failure", {.bool_value = break_on_failure}},
    },
    .activate = [](size_t, auto& n) { return Ret{PushChild, 0}; },
    .resume   = [](size_t, auto& n, ReturnStatus s) {
        if (s == Failed && n.props["break_on_failure"].bool_value) {
          return Ret{Failed};
        }

        int& i = n.props["i"].int_value;
        if (i < n.node->children.size() - 1) {
          i += 1;
          return Ret{PushChild, i};
        }

        return Ret{Succeeded}; },
  };
  return initialize_node(sequence, children);
}


// Succeeder
// ------------------------------------

inline Node Succeeder(NodeChildren children) {
  Node succeeder = {
    .min_children = 0,
    .max_children = 1,
    .activate     = [](size_t, auto& n) { return n.node->children.size() == 0
                                                   ? Ret{Succeeded}
                                                   : Ret{PushChild, 0}; },
    .resume       = [](size_t, auto& n, ReturnStatus s) { return Ret{Succeeded}; },
  };
  return initialize_node(succeeder, children);
}


// While
// ------------------------------------

inline Node While(NodeChildren children) {
  Node n_while = {
    .min_children = 2,
    .max_children = 2,
    .props{
      {"i", {.int_value = 0}},
    },
    .activate = [](size_t, auto& n) { return Ret{PushChild, 0}; },
    .resume   = [](size_t, auto& n, ReturnStatus s) {
        int& i = n.props["i"].int_value;

        // Resume after first child
        if (i == 0) {
          if (s == Succeeded) {
            i += 1;
            return Ret{PushChild, 1};
          }
          else {
            return Ret{Succeeded};
          }
        }
        // After second child
        else {
          i = 0;
          return Ret{PushChild, 0};
        } },
  };
  return initialize_node(n_while, children);
}

}  // namespace Banyan

#endif
