//
// Node_While.h
//
// Repeatedly executes its second node as long as the first node returns Success.
//
// Options:
//
//   - breakOnFailuresIn2ndChild
//     - If true, will cede to parent, returning Failure, if the 2nd node returns Failure.
//     - If false, will ignore the return status of the action node.
//
//       The first case is equivalent to Rep[0, false] - Seq[false] - C1
//                                                                  - C2

#ifndef __Banyan_Node_While_h
#define __Banyan_Node_While_h

#include "Node.h"

namespace Banyan {

  struct While : Node<While> {
    std::string type() { return "While"; }
    ChildLimits childLimits()  { return { 2, 2 }; }


    bool breakOnFailuresIn2ndChild;  // Should failures in the action child
                                     // cease the sequence?

    int i;

    Diatom to_diatom() {
      Diatom d;
      d["breakOnFailuresIn2ndChild"] = breakOnFailuresIn2ndChild;
      return d;
    }
    void from_diatom(Diatom d) {
      breakOnFailuresIn2ndChild = d["breakOnFailuresIn2ndChild"].bool_value;
    }


    While() : i(0), breakOnFailuresIn2ndChild(false) {  }
    ~While() {  }


    NodeReturnStatus activate(int identifier, int _n_children) {
      return { NodeReturnStatus::PushChild, 0 };
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (i == 0) {
        // Act on condition child return status
        if (s.status == NodeReturnStatus::Success) {
          return { NodeReturnStatus::PushChild, ++i };
        }
        else {
          return { NodeReturnStatus::Success };
        }
      }
      else {
        // Act on action child return status
        if (s.status == NodeReturnStatus::Failure && breakOnFailuresIn2ndChild) {
          return { NodeReturnStatus::Failure };
        }
        else {
          return { NodeReturnStatus::PushChild, i=0 };
        }
      }
    }

  };

}

#endif

