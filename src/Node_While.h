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

#ifndef __Node_While_h
#define __Node_While_h

#include "NodeBase.h"

namespace Banyan {

  class While : public NodeBase_CRTP<While> {
  public:
    ChildLimits childLimits()  { return { 2, 2 }; }

    bool breakOnFailuresIn2ndChild;  // Should failures in the action child
                                     // cease the sequence?

    SETTABLES(breakOnFailuresIn2ndChild);

    While() : i(0), breakOnFailuresIn2ndChild(false) {  }
    ~While() {  }

    NodeReturnStatus call(int identifier, int _n_children) {
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

    int i;
  };

}

#endif
