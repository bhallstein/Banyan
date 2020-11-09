//
// NodeRegistry.h
//
// Registry for node types, which are registered by the user.
//  - When a TreeDefinition is created, it copies node objects from these definitions.
//  - A TreeInstance will obtain nodes by copying them from the TreeDef.
//

#ifndef __Banyan_NodeRegistry_h
#define __Banyan_NodeRegistry_h

#include <vector>
#include <string>

#include "Node.h"


namespace Banyan {

  struct NodeRegistry {
    static std::vector<NodeSuper*>& definitions() {
      static std::vector<NodeSuper*> _definitions;
      return _definitions;
    }


    struct AutoRegister {
      AutoRegister(NodeSuper *n) {
        ensureNotAlreadyInDefinitions(n->type());
        definitions().push_back(n);
      };
      AutoRegister(node_function *f, std::string node_type) {
        ensureNotAlreadyInDefinitions(node_type);

        NodeFunctional *n = new NodeFunctional;
        n->f = f;
        n->functional_node_type = node_type;
        definitions().push_back(n);
      }
    };


    static NodeSuper* getNode(std::string node_type) {
      NodeSuper *node = NULL;
      for (auto &n : definitions()) {
        if (n->type() == node_type) {
          node = n;
        }
      }
      return node;
    }


    static void ensureNotAlreadyInDefinitions(std::string node_type) {
      NodeSuper *node = getNode(node_type);
      if (node) {
        throw std::runtime_error(
          std::string("Behaviour already registered: '") + node_type + "'"
        );
      }
    }
  };

}


#define NodeDefinition(class)  \
  Banyan::NodeRegistry::AutoRegister _node_Autoregister_##class(new class)
#define NodeDefinitionFunction(f, node_type)  \
  Banyan::NodeRegistry::AutoRegister _node_Autoregister_##node_type(f, #node_type)


#endif

