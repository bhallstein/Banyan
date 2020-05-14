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
		Diatomize::Descriptor _getSD() {
			Diatomize::Descriptor sd = getSD();
			sd.descriptor.push_back(diatomPart("type", &type));
			
			Diatomize::Descriptor temp;
			for (auto i : s0().descriptor) {  sd.descriptor.push_back(i->clone());  }
			for (auto i : s1().descriptor) {  sd.descriptor.push_back(i->clone());  }
			for (auto i : s2().descriptor) {  sd.descriptor.push_back(i->clone());  }
			for (auto i : s3().descriptor) {  sd.descriptor.push_back(i->clone());  }
			
			return sd;
		}
		
		virtual NodeReturnStatus call(int identifier, int nChildren) = 0;
		virtual NodeReturnStatus resume(int identifier, NodeReturnStatus &s) = 0;
		
		virtual NodeBase* clone(void *into = NULL) = 0;
		virtual int size() = 0;
		
		virtual Diatomize::Descriptor s0() { return {{ }}; }  // The user can override these
		virtual Diatomize::Descriptor s1() { return {{ }}; }  // automatically using SETTABLE()
		virtual Diatomize::Descriptor s2() { return {{ }}; }  // 
		virtual Diatomize::Descriptor s3() { return {{ }}; }  // 
		
		std::string *type;
		
	protected:
		virtual Diatomize::Descriptor getSD() { return { }; }
	};
	
	template<class Derived>
	class NodeBase_CRTP : public NodeBase {
	public:
		NodeBase* clone(void *mem = NULL) {
			NodeBase *n;
			if (mem) n = new (mem) Derived((Derived const &) (*this));
			else     n = new Derived((Derived const &) (*this));
			n->type = type;
			return n;
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
			return Diatomize::Descriptor();
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

#define ConcatL2(a, b) a##b
#define ConcatL1(a, b) ConcatL2(a, b)
#define UniqueVarName(prefix) ConcatL1(prefix, __COUNTER__)

#define SETTABLE(prop_name) \
	Diatomize::Descriptor UniqueVarName(s)() {           \
		return {{ diatomPart(#prop_name, &prop_name) }};  \
	}

#endif
