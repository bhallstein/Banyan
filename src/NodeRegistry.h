//
// NodeRegistry.h
//
// Registry for node types, which are registered by the user.
//  - When a TreeDefinition is created, it copies node objects from these definitions.
//  - A TreeInstance will obtain nodes by copying them from the TreeDef.
//

#ifndef __NodeRegistry_h
#define __NodeRegistry_h

#include <vector>
#include <string>

#include "NodeBase.h"


namespace Banyan {

  struct NodeRegistry {
    static std::vector<NodeBase*>& definitions() {
      static std::vector<NodeBase*> _definitions;
      return _definitions;
    }


    struct AutoRegister {
      AutoRegister(NodeBase *n, std::string node_type) {
        ensureNotAlreadyInDefinitions(node_type);

        n->type = new std::string(node_type);    // - Intentionally leak this memory to create
        definitions().push_back(n);              //   an always-present type string
      };
      AutoRegister(node_function *f, std::string node_type) {
        ensureNotAlreadyInDefinitions(node_type);

        NodeFunctional *n = new NodeFunctional;
        n->f = f;
        n->type = new std::string(node_type);
        definitions().push_back(n);
      }
    };


    static NodeBase* getNode(std::string node_type) {
      NodeBase *node = NULL;
      for (auto &n : definitions()) {
        if (*n->type == node_type) {
          node = n;
        }
      }
      return node;
    }


    static void ensureNotAlreadyInDefinitions(std::string node_type) {
      NodeBase *node = getNode(node_type);
      if (node) {
        throw std::runtime_error(
          std::string("Behaviour already registered: '") + node_type + "'"
        );
      }
    }
  };

}


#define NODE_DEFINITION(class, node_type)  \
  Banyan::NodeRegistry::AutoRegister _node_Autoregister_##node_type(new class, #node_type)
#define NODE_DEFINITION_FN(f, node_type)  \
  Banyan::NodeRegistry::AutoRegister _node_Autoregister_##node_type(f, #node_type)


#endif

