#ifndef __Banyan_Node_Inverter_h
#define __Banyan_Node_Inverter_h

#include "Node.h"

namespace Banyan {

  struct Inverter : Node<Inverter> {
    std::string type() { return "Inverter"; }

    ChildLimits childLimits() { return { 1, 1 }; }

    NodeReturnStatus activate(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      return NodeReturnStatus::invert(s);
    }
  };

}

#endif

