#ifndef __Banyan_Node_Sequence_h
#define __Banyan_Node_Sequence_h

#include "Node.h"

namespace Banyan {

  class Sequence : public Node<Sequence> {
  public:
    ChildLimits childLimits()  { return { 1, -1 }; }

    bool ignoreFailure;

    SETTABLES(ignoreFailure);

    Sequence() : i(0), n_children(-1), ignoreFailure(false) {  }
    ~Sequence() {  }

    NodeReturnStatus call(int identifier, int _n_children) {
      n_children = _n_children;
      return { NodeReturnStatus::PushChild, 0 };
    }
    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (s.status == NodeReturnStatus::Failure && !ignoreFailure)
        return s;

      if (++i == n_children)
        return { NodeReturnStatus::Success };

      return { NodeReturnStatus::PushChild, i };
    }

    int i;
    int n_children;
  };

}

#endif

