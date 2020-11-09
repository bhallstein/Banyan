#ifndef __Banyan_Node_Repeater_h
#define __Banyan_Node_Repeater_h

#include "Node.h"

namespace Banyan {

  class Repeater : public Node<Repeater> {
  public:
    std::string type() { return "Repeater"; }
    ChildLimits childLimits() {
      return { 1, 1 };
    }


    int N;                  // If N is 0, will repeat infinitely
    bool break_on_failure;  // Should failures cease the repeater?

    int i;                  // Number of times repeated


    Diatom to_diatom() {
      Diatom d;
      d["N"] = (double) N;
      d["break_on_failure"] = break_on_failure;
      return d;
    }
    void from_diatom(Diatom d) {
      i = d["i"].value__number;
      N = d["N"].value__number;
      break_on_failure = d["break_on_failure"].value__bool;
    }


    Repeater() : i(0), N(1), break_on_failure(false) {  }
    ~Repeater() {  }


    NodeReturnStatus call(int identifier, int nChildren) {
      return { NodeReturnStatus::PushChild, 0 };
    }


    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      if (s.status == NodeReturnStatus::Failure && break_on_failure) {
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
  };

}

#endif

