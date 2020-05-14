/*
 * Node_Succeeder.h
 *
 */

#ifndef __Node_Succeeder_h
#define __Node_Succeeder_h

#include "NodeDefinition.h"

namespace Banyan {

	class Succeeder : public NodeConcrete {
	public:
		
		class Def : public NodeDefBaseCRTP<Def> {
		public:
			ChildLimits childLimits()  { return { 1, 1 }; }
			NodeConcrete* concreteFactory() { return new Succeeder(this); }
			
			void getSDs(sdvec &vec) { }
			
		};
		
		Succeeder(const Def *_def) :
			NodeConcrete(_def)
		{
			
		}
		
		~Succeeder()
		{
			
		}
		
		
		BehaviourStatus call(int identifier, int nChildren) {
			return { NodeReturnStatus::PushChild, 0 };
		}
		BehaviourStatus resume(int identifier, BehaviourStatus &s) {
			return { NodeReturnStatus::Success };
		}
	};

}

#endif
