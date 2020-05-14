/*
 * Node_MockLeaf.h
 *
 */

#ifndef __NodeDef_MockLeaf_h
#define __NodeDef_MockLeaf_h

#include "NodeDefinition.h"

class MockLeaf : public NodeConcrete {
public:
	
	class Def : public NodeDefBaseCRTP<Def> {
	public:
		ChildLimits childLimits()  { return { 0, 0 }; }
		NodeConcrete* concreteFactory() { return new MockLeaf(this); }
		
		bool succeeds;	// Returns success or failure?
		
		void getSDs(sdvec &vec) {
			static serialization_descriptor sd = {
				{ "succeeds",           makeSerializer(&Def::succeeds) }
			};
			vec.push_back(&sd);
		}
	};
	
	MockLeaf(const Def *_def) :
		NodeConcrete(_def),
		succeeds(_def->succeeds)
	{
		n_times_created += 1;
	}
	~MockLeaf()
	{
		
	}
	
	static int n_times_created;
	static int n_times_called;
	static int n_times_resumed;
	
	BehaviourStatus call(int identifier, int nChildren) {;
		n_times_called += 1;
		
		BehaviourStatus ret;
		ret.status = succeeds ? NodeReturnStatus::Success : NodeReturnStatus::Failure;
		return ret;
	}
	BehaviourStatus resume(int identifier, BehaviourStatus &s) {
		// This should not be called, as we are a leaf node.
		n_times_resumed += 1;
		return s;
	}
	
	const bool succeeds;
};



#endif
