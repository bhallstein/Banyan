/*
 * Node_Selector.h
 *
 */

#ifndef __Node_Selector_h
#define __Node_Selector_h

#include "NodeBase.h"
#include <algorithm>
#include <random>

namespace Banyan {

	class Selector : public NodeBase_CRTP<Selector> {
	public:
		ChildLimits childLimits() { return { 1, -1 }; }
		
		bool stopAfterFirstSuccess;  // Return success after a child succeeds
		bool randomizeOrder;         // Call children in random order?
		
		SETTABLES(stopAfterFirstSuccess, randomizeOrder);

		Selector() : i(0), n_children(-1), stopAfterFirstSuccess(true), randomizeOrder(false) {  }
		~Selector() {  }
		
		NodeReturnStatus call(int identifier, int _n_children) {
			n_children = _n_children;
			children = vectorUpTo(n_children, randomizeOrder);
			
			return { NodeReturnStatus::PushChild, children[0] };
		}
		NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
			if (s.status == NodeReturnStatus::Success && stopAfterFirstSuccess)
				return { NodeReturnStatus::Success };
			
			if (++i == n_children)
				return s;
			
			return { NodeReturnStatus::PushChild, children[i] };
		}
		
		int i;
		int n_children;
		std::vector<int> children;
		
	private:
		static std::vector<int> vectorUpTo(int n, bool randomize) {
			static std::random_device rd;
			static std::mt19937 g(rd());
			
			std::vector<int> v;
			
			for (int i=0; i < n; ++i)
				v.push_back(i);
			
			if (randomize)
				std::shuffle(v.begin(), v.end(), g);
			
			return v;
		}
		
	};

}

#endif
