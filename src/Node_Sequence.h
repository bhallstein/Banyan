#ifndef __Banyan_Node_Sequence_h
#define __Banyan_Node_Sequence_h

#include "Node.h"

namespace Banyan {

  struct Sequence : Node<Sequence> {
    std::string type() { return "Sequence"; }
    ChildLimits childLimits()  { return { 1, -1 }; }

    bool break_on_failure;
    int i;
    int n_children;

    Sequence() : i(0), n_children(-1), break_on_failure(false) {  }

    Diatom to_diatom() {
      Diatom d;
      d["break_on_failure"] = break_on_failure;
      return d;
    }
    void from_diatom(Diatom d) {
      break_on_failure = d["break_on_failure"].bool_value;
    }

    NodeReturnStatus activate(int identifier, int _n_children) {
      n_children = _n_children;
      return { NodeReturnStatus::PushChild, 0 };
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (s.status == NodeReturnStatus::Failure && break_on_failure) {
        return s;
      }

      if (++i == n_children) {
        return { NodeReturnStatus::Success };
      }

      return { NodeReturnStatus::PushChild, i };
    }
  };

}

#endif
