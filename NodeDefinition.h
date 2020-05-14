/*
 * NodeDefinition.h
 *
 * Node parent classes.
 * 
 */

#ifndef __NodeDefinition_h
#define __NodeDefinition_h

#include <vector>
#include <string>
#include <stdexcept>

#include "BanyanThrow.h"

#ifndef __BANYAN_DISABLE_THROWS
	#define __LS_THROW_ON_MISSING_VALUES 1
#endif
#include "LSSerializable.hpp"
#include "LSSerializer.hpp"

namespace Banyan {

	class NodeConcrete;

	namespace NodeReturnStatus {
		enum T {
			Success,
			Failure,
			Running,
			PushChild
		};
	}

	struct BehaviourStatus {
		NodeReturnStatus::T status;
		int child; 	// index in the children array
	};

	class NodeDef : public Serializable {
	public:
		NodeDef() : Serializable(Serializable::ErrorBehaviour::Throw) { }
		
		struct ChildLimits {
			int min, max;
		};
		
		virtual ChildLimits childLimits()                    = 0;
		virtual NodeConcrete* concreteFactory() = 0;
		virtual NodeDef* clone()                             = 0;
		
		// Node definition registrations.
		// NB. this will presumably go in a BT class, in fact?
		
		typedef BehaviourStatus (node_function)(int identifier, int nChildren);
		struct Type {
			enum T { Class, Function };	
		};
		
		struct Wrapper {
			union {
				NodeDef *nodeDef;
				node_function *nodeFn;
			};
			Type::T type;
			std::string identifier;
			std::string symbol;
			
			Wrapper(NodeDef *_nd, const std::string &_id, const std::string &_sym) :
				nodeDef(_nd),
				type(Type::Class),
				identifier(_id),
				symbol(_sym)
			{
				
			}
			Wrapper(node_function *_f, const std::string &_id, const std::string &_sym) :
				nodeFn(_f),
				type(Type::Function),
				identifier(_id),
				symbol(_sym)
			{
				
			}
		};
		
		static std::vector<Wrapper>& definitions() {
			static std::vector<Wrapper> _definitions;
			return _definitions;
		}
		
		static bool exc_thrown(bool set, bool newval) {
			static bool thrown = false;
			if (set) thrown = newval;
			return thrown;
		}
			// Used to propagate errors to main when compiled as a library & exceptions
			// turned off.
		
		struct AutoRegister {
			AutoRegister(NodeDef *n, const std::string &id, const std::string &sym) {
				printf("registering node type: %s\n", id.c_str());
				ensureNotAlreadyInDefinitions(id, sym);
				definitions().push_back(Wrapper(n, id, sym));
			};
			AutoRegister(node_function *f, const std::string &id, const std::string &sym) {
				printf("registering node type: %s\n", id.c_str());
				ensureNotAlreadyInDefinitions(id, sym);
				definitions().push_back(Wrapper(f, id, sym));
			}
			void ensureNotAlreadyInDefinitions(const std::string &id, const std::string &sym) {
				auto &defs = definitions();
				for (auto &i : defs) {
					if (i.identifier.compare(id) == 0)
						_bnyn_throw(
							(std::string("Behaviour already registered: '") +
							id + "'").c_str()
						);
					else if (i.symbol.compare(sym) == 0)
						_bnyn_throw(
							(std::string("Behaviour symbol already imported: '") +
							sym + "'").c_str()
						);
				}
			}
		};
	};

	template <typename Derived>
	class NodeDefBaseCRTP : public NodeDef {
	public:
		virtual NodeDef* clone() {
			return new Derived((Derived const&)(*this));
		}
	};
	
	
	class NodeConcrete {
	public:
		NodeConcrete(const NodeDef *_d) : _def(_d) { }
		// - Created when pushed. Therefore, perform any necessary setup in the constructor.
		
		virtual BehaviourStatus call(int identifier, int nChildren) = 0;
		// - After creation, is call()'d, and returns S/F/R/PC[n].
		
		virtual BehaviourStatus resume(int identifier, BehaviourStatus &s) = 0;
		// - Called when a child returns. May use the return value of the child to
		//   decide the BehaviourStatus to return.
		
		virtual ~NodeConcrete() { }
		
		const NodeDef *_def;
		
		struct Wrapper {
			union {
				NodeConcrete *nc;
				NodeDef::node_function *nf;
			};
			NodeDef::Type::T type;
		};
	};
	
}


#define ConcatL2(a, b) a##b
#define ConcatL1(a, b) ConcatL2(a, b)
#define NODE_DEFINITION(ident, sym) \
	Banyan::NodeDef::AutoRegister _node_Autoregister_##ident(  \
		new sym,    \
		#ident,      \
		#sym        \
	)
#define NODE_DEFINITION_FN(ident, sym) \
	Banyan::NodeDef::AutoRegister _node_Autoregister_##ident(  \
		sym,        \
		#ident,      \
		#sym        \
	)

#endif

