#ifndef Banyan_h
#define Banyan_h

#include <vector>
#include <string>
#include <stdexcept>
#include <random>
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
  int child;
};

struct Prop {
  union {
    bool bool_value;
    int int_value;
    float float_value;
  };
  std::string string_value;
};

template<class T>
void scramble(std::vector<T> &v) {
  std::random_device rd;
  std::mt19937 g(rd());
  std::shuffle(v.begin(), v.end(), g);
}


// RunNode
// ------------------------------------

struct Node {
  struct RunNode {   // Copy of node without children used when running tree
    Node *node;
    Map<Prop> props;
    RunNode(Node *n) : node(n), props(n->props) { }

    Ret activate(size_t identifier) {
      return node->activate(identifier, *this);
    }
    Ret resume(size_t identifier, ReturnStatus status) {
      return node->resume(identifier, *this, status);
    }
  };

  int min_children = 0;
  int max_children = 0;   // If -1, no maximum
  Map<Prop> props;

  typedef std::function<Ret(size_t, RunNode&)> activate_func;
  typedef std::function<Ret(size_t, RunNode&, ReturnStatus)> resume_func;

  activate_func activate = [](size_t identifier, RunNode&) {
    return Ret{Succeeded};
  };
  resume_func resume = [](size_t identifier, RunNode&, ReturnStatus) {
    return Ret{Succeeded};
  };

  std::vector<Node> children;
};


// NodeInitializer - used to initialize nodes in construct()
// ------------------------------------

struct NodeInitializer {
  Node node;
  Map<Prop> props;
  std::vector<NodeInitializer> children;
};


// construct() - function to initialize a tree
// ------------------------------------

inline Node construct(NodeInitializer init) {
  Node node = init.node;
  auto n_children = init.children.size();

  bool n_children_invalid = (
    n_children < node.min_children ||
    (node.max_children != -1 && n_children > node.max_children)
  );
  if (n_children_invalid) {
    throw std::runtime_error("Error: node has invalid number of children");
  }

  for (auto &p : init.props.entries) {
    node.props[p.name] = p.item;
  }
  for (auto &ch : init.children) {
    node.children.push_back(construct(ch));
  }

  return node;
}


// TreeInstance
// ------------------------------------

struct Instance {
  Node *tree;
  size_t identifier;
  std::vector<Node::RunNode> stack;

  Instance(Node *_tree, size_t _identifier) : tree(_tree), identifier(_identifier) { }

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
        Node::RunNode &rn = stack.back();
        ret = rn.resume(identifier, ret.status);
      }

      else if (ret.status == PushChild) {
        stack.push_back(Node::RunNode(&stack.back().node->children[ret.child]));
        ret = stack.back().activate(identifier);
      }
    }
  }
};


// Built-in node definitions
// ------------------------------------

inline Node Inverter() {
  return {
    .min_children = 1,
    .max_children = 1,
    .activate = [](size_t, auto &n) {
      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) {
      return Ret{.status = s == Failed ? Succeeded : Failed};
    },
  };
}

inline Node Repeater() {
  return {
    .min_children = 1,
    .max_children = 1,
    .props = {
      {"i", {.int_value = 0}},
      {"N", {.int_value = 1}},  // If 0, repeat infinitely
      {"break_on_failure", {.bool_value = false}},
    },
    .activate = [](size_t, auto &n) {
      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) {
      if (s == Failed && n.props["break_on_failure"].bool_value) {
        return Ret{Failed};
      }

      if (n.props["N"].int_value == 0) {
        return Ret{PushChild, 0};
      }

      int &N = n.props["N"].int_value;
      int &i = n.props["i"].int_value;
      i += 1;

      if (N == 0 || i < N) {
        return Ret{PushChild, 0};
      }

      return Ret{Succeeded};
    },
  };
}

inline Node Selector() {
  return {
    .min_children = 1,
    .max_children = -1,
    .props = {
      {"i", {.int_value = 0}},
      {"stop_after_first_success", {.bool_value = false}},
      {"random_order", {.bool_value = 0}},
    },
    .activate = [](size_t, auto &n) {
      if (n.props["random_order"].bool_value) {
        scramble(n.node->children);   // TODO: fix
      }

      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) -> Ret {
      if (s == Succeeded && n.props["stop_after_first_success"].bool_value) {
        return {Succeeded};
      }

      int &i = n.props["i"].int_value;
      if (i < n.node->children.size() - 1) {
        i += 1;
        return Ret{PushChild, i};
      }

      return Ret{s};
    },
  };
}

inline Node Sequence() {
  return {
    .min_children = 1,
    .max_children = -1,
    .props = {
      {"break_on_failure", {.bool_value = false}},
      {"i", {.int_value = 0}},
    },
    .activate = [](size_t, auto &n) {
      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) {
      if (s == Failed && n.props["break_on_failure"].bool_value) {
        return Ret{Failed};
      }

      int &i = n.props["i"].int_value;
      if (i < n.node->children.size() - 1) {
        i += 1;
        return Ret{PushChild, i};
      }

      return Ret{Succeeded};
    },
  };
}

inline Node Succeeder() {
  return {
    .min_children = 1,
    .max_children = 1,
    .activate = [](size_t, auto &n) {
      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) {
      return Ret{Succeeded};
    },
  };
}

inline Node While() {
  return {
    .min_children = 2,
    .max_children = 2,
    .props{
      {"i", {.int_value = 0}},
    },
    .activate = [](size_t, auto &n) {
      return Ret{PushChild, 0};
    },
    .resume = [](size_t, auto &n, ReturnStatus s) {
      int &i = n.props["i"].int_value;

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
      }
    },
  };
}

}

#endif

