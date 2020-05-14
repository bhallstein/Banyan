/*
 * Node_Repeater.h
 *
 */

#ifndef __Node_Repeater_h
#define __Node_Repeater_h

#include "NodeBase.h"

namespace Banyan {

	class Repeater : public NodeBase_CRTP<Repeater> {
	public:
		ChildLimits childLimits() { return { 1, 1 }; }
		Diatomize::Descriptor getSD() {
			return {{
				diatomPart("N", &N),
				diatomPart("ignoreFailure", &ignoreFailure)
			}};
		}
		
		int N;               // Set N to 0 to repeat infinitely
		bool ignoreFailure;  // Should failures cease the repeater?
		
		Repeater() : i(0) {  }
		~Repeater() {  }
		
		NodeReturnStatus call(int identifier, int nChildren) {
			return { NodeReturnStatus::PushChild, 0 };
		}
		NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
			if (s.status == NodeReturnStatus::Failure && !ignoreFailure)
				return s;
			
			if (N == 0) return { NodeReturnStatus::PushChild, 0 };
			
			if (++i == N) return { NodeReturnStatus::Success };
			
			return { NodeReturnStatus::PushChild, 0 };
		}
		
		int i;
	};

}

#endif
