#ifndef __Banyan_Node_Succeeder_h
#define __Banyan_Node_Succeeder_h

#include "Node.h"

namespace Banyan {

  struct Succeeder : Node<Succeeder> {
    std::string type() { return "Succeeder"; }
    ChildLimits childLimits()  { return { 1, 1 }; }

    Succeeder() {  }
    ~Succeeder() {  }

    NodeReturnStatus activate(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }
    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      return { NodeReturnStatus::Success };
    }
  };

}

#endif

