
#ifndef __Test_BTInst_registerTestNodes_h
#define __Test_BTInst_registerTestNodes_h

#include "Banyan.h"

// MockLeaf class-type node

class MockLeaf : public Banyan::NodeConcrete {
public:
	
	class Def : public Banyan::NodeDefBaseCRTP<Def> {
	public:
		ChildLimits childLimits()  { return { 0, 0 }; }
		NodeConcrete* concreteFactory() { return new MockLeaf(this); }
		
		bool succeeds;	// Returns success or failure?
		
		void getSDs(sdvec &vec) {
			static serialization_descriptor sd = {
				{ "succeeds", makeSerializer(&Def::succeeds) }
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
	
	static void reset() {
		n_times_created = 0;
		n_times_called  = 0;
		n_times_resumed = 0;
	}
	
	static int n_times_created;
	static int n_times_called;
	static int n_times_resumed;
	
	Banyan::BehaviourStatus call(int identifier, int nChildren) {;
		n_times_called += 1;
		
		Banyan::BehaviourStatus ret;
		ret.status = succeeds ? Banyan::NodeReturnStatus::Success : Banyan::NodeReturnStatus::Failure;
		return ret;
	}
	Banyan::BehaviourStatus resume(int identifier, Banyan::BehaviourStatus &s) {
		// This should not be called, as we are a leaf node.
		n_times_resumed += 1;
		return s;
	}
	
	const bool succeeds;
};



// Function-type nodes

Banyan::BehaviourStatus someNodeFunction(int identifier, int n_children);
Banyan::BehaviourStatus nodeFnThatFailsEventually(int id, int nch);

extern int _fn_node_calls;
extern int _fn_node_calls_2;

#endif
