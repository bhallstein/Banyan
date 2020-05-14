/*
 * Node_Sequence.h
 *
 */

#ifndef __Node_Sequence_h
#define __Node_Sequence_h

#include "NodeDefinition.h"

class Sequence : public NodeConcrete {
public:
	
	class Def : public NodeDefBaseCRTP<Def> {
	public:
		ChildLimits childLimits()  { return { 1, -1 }; }
		NodeConcrete* concreteFactory() { return new Sequence(this); }
		
		bool ignoreFailure;
		
		void getSDs(sdvec &vec) {
			static serialization_descriptor sd = {
				{ "ignoreFailure", makeSerializer(&Def::ignoreFailure) }
			};
			vec.push_back(&sd);
		}
	};
	
	Sequence(const Def *_def) :
		NodeConcrete(_def),
		i(0),
		n_children(-1),
		ignoreFailures(_def->ignoreFailure)
	{
		
	}
	
	~Sequence()
	{
		
	}
	
	
	BehaviourStatus call(int identifier, int _n_children) {
		n_children = _n_children;
		return { NodeReturnStatus::PushChild, 0 };
	}
	BehaviourStatus resume(int identifier, BehaviourStatus &s) {
		if (s.status == NodeReturnStatus::Failure && !ignoreFailures)
			return s;
		
		if (++i == n_children) return { NodeReturnStatus::Success };
		
		return { NodeReturnStatus::PushChild, i };
	}
	
	int i;
	int n_children;
	const bool ignoreFailures;
};

#endif
