/*
 * NodeRegistry.h
 *
 * Registry for node types, which are registered by the user.
 *
 * When a TreeDefinition is created, it copies the node object from these definitions,
 * and then deserializes it using the tree file.
 *
 * A TreeInstance will then copy nodes from the TreeDef, to obtain them, including their
 * per-instance settings.
 *
 */

#ifndef __NodeRegistry_h
#define __NodeRegistry_h

#include <vector>
#include <string>

#include "NodeBase.h"

namespace Banyan {

	class NodeRegistry {
	public:
		
		struct Wrapper {
			NodeBase *node;
			std::string identifier;
			
			Wrapper(NodeBase *_n, const std::string &_id) :
				node(_n),
				identifier(_id)
			{  }
			~Wrapper()
			{
				delete node;
			}
		};
		
		static std::vector<Wrapper*>& definitions() {
			static std::vector<Wrapper*> _definitions;
			return _definitions;
		}
		
		static void unregisterAll() {
			for (auto &i : definitions())
				delete i;
			definitions().clear();
		}
		
		struct AutoRegister {
			AutoRegister(NodeBase *n, const std::string &id) {
				// printf("registering node: %s  (%lu)\n", id.c_str(), definitions().size()+1);
				ensureNotAlreadyInDefinitions(id);
				definitions().push_back(new Wrapper(n, id));
			};
			AutoRegister(node_function *f, const std::string &id) {
				// printf("registering node: %s  (%lu)\n", id.c_str(), definitions().size()+1);
				ensureNotAlreadyInDefinitions(id);
				NodeFunctional *n = new NodeFunctional;
				n->f = f;
				definitions().push_back(new Wrapper(n, id));
			}
			void ensureNotAlreadyInDefinitions(const std::string &id) {
				auto &defs = definitions();
				for (auto &i : defs)
					if (i->identifier.compare(id) == 0)
						throw std::runtime_error(
							std::string("Behaviour already registered: '") + id + "'"
						);
			}
		};
	
	};

}


#define ConcatL2(a, b) a##b
#define ConcatL1(a, b) ConcatL2(a, b)
#define NODE_DEFINITION(sym, ident)  \
	Banyan::NodeRegistry::AutoRegister _node_Autoregister_##ident(  \
		new sym, #ident  \
	)
#define NODE_DEFINITION_FN(sym, ident)  \
	Banyan::NodeRegistry::AutoRegister _node_Autoregister_##ident(  \
		sym, #ident  \
	)


#endif
