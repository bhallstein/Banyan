/*
 * Node_Repeater.h
 *
 */

#ifndef __Node_Repeater_h
#define __Node_Repeater_h

#include "NodeDefinition.h"

namespace Banyan {

	class Repeater : public NodeConcrete {
	public:
		
		class Def : public NodeDefBaseCRTP<Def> {
		public:
			ChildLimits childLimits()  { return { 1, 1 }; }
			NodeConcrete* concreteFactory() { return new Repeater(this); }
			
			int N;               // Set N to 0 to repeat infinitely
			bool ignoreFailure;  // Should failures cease the repeater?
			
			void getSDs(sdvec &vec) {
				static serialization_descriptor sd = {
					{ "N",             makeSerializer(&Def::N) },
					{ "ignoreFailure", makeSerializer(&Def::ignoreFailure) }
				};
				vec.push_back(&sd);
			}
		};
		
		Repeater(const Def *_def) :
			NodeConcrete(_def),
			i(0),
			N(_def->N),
			ignoreFailures(_def->ignoreFailure)
		{
			
		}
		
		~Repeater()
		{
			
		}
		
		
		BehaviourStatus call(int identifier, int nChildren) {
			return { NodeReturnStatus::PushChild, 0 };
		}
		BehaviourStatus resume(int identifier, BehaviourStatus &s) {
			if (s.status == NodeReturnStatus::Failure && !ignoreFailures)
				return s;
			
			if (N == 0) return { NodeReturnStatus::PushChild, 0 };
			
			if (++i == N) return { NodeReturnStatus::Success };
			
			return { NodeReturnStatus::PushChild, 0 };
		}
		
		int i;
		const int N;
		const bool ignoreFailures;
	};

}

#endif
