#ifndef __Banyan_Node_Selector_h
#define __Banyan_Node_Selector_h

#include "Node.h"
#include <algorithm>
#include <random>

namespace Banyan {

  struct Selector : Node<Selector> {
    std::string type() { return "Selector"; }
    ChildLimits childLimits() { return { 1, -1 }; }


    bool stopAfterFirstSuccess;  // Return success after a child succeeds
    bool randomizeOrder;         // Call children in random order?

    int i;
    int n_children;
    std::vector<int> children;


    Diatom to_diatom() {
      Diatom d;
      d["stopAfterFirstSuccess"] = stopAfterFirstSuccess;
      d["randomizeOrder"] = randomizeOrder;
      return d;
    }
    void from_diatom(Diatom d) {
      stopAfterFirstSuccess = d["stopAfterFirstSuccess"].value__bool;
      randomizeOrder = d["randomizeOrder"].value__bool;
    }


    Selector() : i(0), n_children(-1), stopAfterFirstSuccess(true), randomizeOrder(false) {  }
    ~Selector() {  }


    NodeReturnStatus call(int identifier, int _n_children) {
      n_children = _n_children;
      children = vectorUpTo(n_children, randomizeOrder);

      return { NodeReturnStatus::PushChild, children[0] };
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (s.status == NodeReturnStatus::Success && stopAfterFirstSuccess) {
        return { NodeReturnStatus::Success };
      }

      if (++i == n_children) {
        return s;
      }

      return { NodeReturnStatus::PushChild, children[i] };
    }

    static std::vector<int> vectorUpTo(int n, bool randomize) {
      static std::random_device rd;
      static std::mt19937 g(rd());

      std::vector<int> v;

      for (int i=0; i < n; ++i) {
        v.push_back(i);
      }

      if (randomize) {
        std::shuffle(v.begin(), v.end(), g);
      }

      return v;
    }

  };

}

#endif

