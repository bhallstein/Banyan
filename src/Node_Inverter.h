#ifndef __Banyan_Node_Inverter_h
#define __Banyan_Node_Inverter_h

#include "Node.h"

namespace Banyan {

  class Inverter : public Node<Inverter> {
  public:
    std::string type() { return "Inverter"; }
    ChildLimits childLimits() { return { 1, 1 }; }

    Inverter() {  }
    ~Inverter() {  }

    NodeReturnStatus call(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }
    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      return NodeReturnStatus::invert(s);
    }
  };

}

#endif

