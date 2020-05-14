/*
 * Node_Succeeder.h
 *
 */

#ifndef __Node_Succeeder_h
#define __Node_Succeeder_h

#include "NodeBase.h"

namespace Banyan {
	
	class Succeeder : public NodeBase_CRTP<Succeeder> {
	public:
		ChildLimits childLimits()  { return { 1, 1 }; }
		Diatomize::Descriptor getSD() {
			static Diatomize::Descriptor sd;
			return sd;
		}
		
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
