/*
 * NodeBase.h
 *
 *
 */

#ifndef __NodeBase_h
#define __NodeBase_h

#include <new>

#include "Diatomize.h"
#include <stdexcept>

namespace Banyan {
	
	struct NodeReturnStatus {
		enum T {
			Success,
			Failure,
			Running,
			PushChild
		};
		T status;
		int child;
		
		static NodeReturnStatus invert(const NodeReturnStatus &s) {
			return (NodeReturnStatus) { s.status == Success ? Failure : Success };
		}
	};
	
	struct ChildLimits {
		int min, max;
	};
	
	typedef NodeReturnStatus (node_function)(int identifier);
	
	class NodeBase {
	public:
		virtual ~NodeBase() {  }
		
		virtual ChildLimits childLimits() = 0;
		virtual Diatomize::Descriptor getSD() = 0;
		
		virtual NodeReturnStatus call(int identifier, int nChildren) = 0;
		virtual NodeReturnStatus resume(int identifier, NodeReturnStatus &s) = 0;

		virtual NodeBase* clone(void *into = NULL) = 0;
		virtual int size() = 0;
	};
	
	template<class Derived>
	class NodeBase_CRTP : public NodeBase {
	public:
		NodeBase* clone(void *mem = NULL) {
			if (mem) return new (mem) Derived((Derived const &) (*this));
			else     return new Derived((Derived const &) (*this));
		}
		int size() { return sizeof(Derived); }
			// CRTP superclass
			// - Calling clone() on a subclass will invoke this method, calling the
			//   subclass’s copy constructor.
			// - Especially for classes with automatically-generated copy constructors,
			//   this is super convenient.
	};

	class NodeFunctional : public NodeBase_CRTP<NodeFunctional> {
	public:
		ChildLimits childLimits() { return { 0, 0}; }
		Diatomize::Descriptor getSD() {
			static Diatomize::Descriptor sd;
			return sd;
		}
		
		NodeReturnStatus call(int identifier, int nChildren) {
			return f(identifier);
		}
		NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
			throw std::runtime_error("resume() called on functional node");
			return s;
		}
		
		node_function *f;
	};

}

#endif
