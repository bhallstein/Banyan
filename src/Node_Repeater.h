#ifndef __Banyan_Node_Repeater_h
#define __Banyan_Node_Repeater_h

#include "Node.h"

namespace Banyan {

  class Repeater : public Node<Repeater> {
  public:
    ChildLimits childLimits() {
      return { 1, 1 };
    }

    int N;               // Set N to 0 to repeat infinitely
    bool ignoreFailure;  // Should failures cease the repeater?

    SETTABLES(N, ignoreFailure);

    Repeater() : i(0), N(1), ignoreFailure(false) {  }
    ~Repeater() {  }

    NodeReturnStatus call(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }
    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (s.status == NodeReturnStatus::Failure && !ignoreFailure) {
        return s;
      }

      if (N == 0) {
        return { NodeReturnStatus::PushChild, 0 };
      }

      if (++i == N) {
        return { NodeReturnStatus::Success };
      }

      return { NodeReturnStatus::PushChild, 0 };
    }

    int i;
  };

}

#endif

