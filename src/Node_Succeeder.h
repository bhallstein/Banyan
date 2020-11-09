#ifndef __Banyan_Node_Succeeder_h
#define __Banyan_Node_Succeeder_h

#include "Node.h"

namespace Banyan {

  class Succeeder : public Node<Succeeder> {
  public:
    ChildLimits childLimits()  { return { 1, 1 }; }

    Succeeder() {  }
    ~Succeeder() {  }

    NodeReturnStatus call(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }
    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      return { NodeReturnStatus::Success };
    }
  };

}

#endif

