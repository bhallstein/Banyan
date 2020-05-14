/*
 * Node_Selector.h
 *
 */

#ifndef __Node_Selector_h
#define __Node_Selector_h

#include "NodeDefinition.h"
#include <algorithm>
#include <random>

namespace Banyan {

	class Selector : public NodeConcrete {
	public:
		
		class Def : public NodeDefBaseCRTP<Def> {
		public:
			ChildLimits childLimits()  { return { 1, -1 }; }
			NodeConcrete* concreteFactory() { return new Selector(this); }
			
			bool stopAfterFirstSuccess;  // Should a  cease the selector?
			bool randomizeOrder;         // Call children in random order?
			
			void getSDs(sdvec &vec) {
				static serialization_descriptor sd = {
					{ "stopAfterFirstSuccess",  makeSerializer(&Def::stopAfterFirstSuccess) },
					{ "randomizeOrder",         makeSerializer(&Def::randomizeOrder) },
				};
				vec.push_back(&sd);
			}
		};
		
		Selector(const Def *_def) :
			NodeConcrete(_def),
			i(0),
			n_children(-1),
			randomizeOrder(_def->randomizeOrder),
			stopAfterFirstSuccess(_def->stopAfterFirstSuccess)
		{
			// printf("\nRepeater created\n");
		}
		
		~Selector()
		{
			// printf("Repeater destroyed\n");
		}
		
		
		BehaviourStatus call(int identifier, int _n_children) {
			n_children = _n_children;
			children = vectorUpTo(n_children, randomizeOrder);
			
			return { NodeReturnStatus::PushChild, children[0] };
		}
		BehaviourStatus resume(int identifier, BehaviourStatus &s) {
			if (s.status == NodeReturnStatus::Success && stopAfterFirstSuccess)
				return { NodeReturnStatus::Success };
			
			if (++i == n_children)
				return s;
			
			else
				return { NodeReturnStatus::PushChild, children[i] };
		}
		
		const bool randomizeOrder;
		const bool stopAfterFirstSuccess;
		
		int i;
		int n_children;
		std::vector<int> children;
		
	private:
		std::vector<int> vectorUpTo(int n, bool randomize) {
			std::vector<int> v;
			
			for (int i=0; i < n; ++i)
				v.push_back(i);
			
			if (randomize) {
				std::random_device rd;
				std::mt19937 g(rd());
				std::shuffle(v.begin(), v.end(), g);
			}
			
			return v;
		}
		
	};

}

#endif
