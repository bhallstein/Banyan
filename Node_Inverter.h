/*
 * Node_Inverter.h
 *
 */

#ifndef __Node_Inverter_h
#define __Node_Inverter_h

#include "NodeDefinition.h"

namespace Banyan {

	class Inverter : public NodeConcrete {
	public:
		
		class Def : public NodeDefBaseCRTP<Def> {
		public:
			ChildLimits childLimits()  { return { 1, 1 }; }
			NodeConcrete* concreteFactory() { return new Inverter(this); }
			
			void getSDs(sdvec &vec) { }	
		};
		
		Inverter(const Def *_def) :
			NodeConcrete(_def)
		{
			
		}
		
		~Inverter()
		{
			
		}
		
		
		BehaviourStatus call(int identifier, int nChildren) {
			return { NodeReturnStatus::PushChild, 0 };
		}
		BehaviourStatus resume(int identifier, BehaviourStatus &s) {
			BehaviourStatus ret = {
				s.status == NodeReturnStatus::Success ?
					NodeReturnStatus::Failure :
					NodeReturnStatus::Success
			};
			return ret;
		}
	};

}

#endif
