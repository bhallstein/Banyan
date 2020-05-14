/*
 * Node_Inverter.h
 *
 */

#ifndef __Node_Inverter_h
#define __Node_Inverter_h

#include "NodeBase.h"

namespace Banyan {

	class Inverter : public NodeBase_CRTP<Inverter> {
	public:
		ChildLimits childLimits() { return { 1, 1 }; }
		Diatomize::Descriptor getSD() {
			static Diatomize::Descriptor sd;
			return sd;
		}
		
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
