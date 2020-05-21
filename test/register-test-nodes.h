
#ifndef __Test_BTInst_registerTestNodes_h
#define __Test_BTInst_registerTestNodes_h

#include "../Banyan.h"

// MockLeaf class-type node

class MockLeaf : public Banyan::NodeBase_CRTP<MockLeaf> {
public:
	
	Banyan::ChildLimits childLimits()  { return { 0, 0 }; }
		
	bool succeeds;	// Returns success or failure?
	
	Diatomize::Descriptor getSD() {
		return {{
			diatomPart("succeeds", &succeeds)
		}};
	}
	
	MockLeaf()  { n_times_created += 1; }
	MockLeaf(const MockLeaf &m) : succeeds(m.succeeds) { n_times_created += 1; }
	~MockLeaf() {  }
	
	static void reset() {
		n_times_created = 0;
		n_times_called  = 0;
		n_times_resumed = 0;
	}
	
	static void print() {
        printf("n_times_created: %d\n", n_times_created);
        printf("n_times_called : %d\n", n_times_called );
		printf("n_times_resumed: %d\n", n_times_resumed);
	}
	
	static int n_times_created;
	static int n_times_called;
	static int n_times_resumed;
	
	Banyan::NodeReturnStatus call(int identifier, int nChildren) {
		n_times_called += 1;
		return (Banyan::NodeReturnStatus) {
			(succeeds ? Banyan::NodeReturnStatus::Success : Banyan::NodeReturnStatus::Failure)
		};
	}
	Banyan::NodeReturnStatus resume(int identifier, Banyan::NodeReturnStatus &s) {
		// This should not be called, as we are a leaf node.
		_assert(false);
		n_times_resumed += 1;
		return s;
	}
};



// Function-type nodes

Banyan::NodeReturnStatus someNodeFunction(int identifier);
Banyan::NodeReturnStatus nodeFnThatFailsEventually(int id);

extern int _fn_node_calls;
extern int _fn_node_calls_2;

#endif
