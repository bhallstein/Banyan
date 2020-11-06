//
// TreeDefinition.h
//
// A TreeDefinition defines the structure for 1 or many TreeInstance objects.
//
// This means the entire tree does not have to be duplicated for every instance,
// which can instead maintain only a stack of current nodes.
//
// TreeInstance creates nodes by copying them from the TreeDefinition.
//

#ifndef __TreeDef_h
#define __TreeDef_h

#include "src/NodeBase.h"
#include "src/NodeRegistry.h"

#define _GT_ENABLE_SERIALIZATION
#include "GenericTree/GenericTree_Nodeless.h"

#include "src/Node_Repeater.h"
#include "src/Node_Inverter.h"
#include "src/Node_Succeeder.h"
#include "src/Node_Sequence.h"
#include "src/Node_Selector.h"
#include "src/Node_While.h"

#include <stdexcept>

namespace Banyan {

  class TreeDefinition : public GenericTree_Nodeless {
    typedef GenericTree_Nodeless super;

  public:
    TreeDefinition() { registerBuiltins(); }
    ~TreeDefinition() { reset(); }

    void reset() {
      for (auto &i : treedef_nodes) {
        delete i;
      }
      treedef_nodes.clear();
      super::reset();
    }

    static void registerBuiltins() {
      static bool loaded = false;
      if (!loaded) {
        NODE_DEFINITION(Repeater, Repeater);   // Decorators
        NODE_DEFINITION(Inverter, Inverter);
        NODE_DEFINITION(Succeeder, Succeeder);

        NODE_DEFINITION(Sequence, Sequence);   // Composites
        NODE_DEFINITION(Selector, Selector);
        NODE_DEFINITION(While, While);

        loaded = true;
      }
    }

    NodeBase* getNode(int i) {
      return treedef_nodes[i];
    }

    // Serialization
    // ------------------------------------------
    // The serialized form of the TreeDef is:
    //    treedef:
    //       nodes: { node, ... },
    //       tree:  <generictree serialization>

    Diatom toDiatom() {
      Diatom treedef;

      treedef["nodes"] = Diatom();
      int i = 0;
      for (auto &n : treedef_nodes) {
        treedef["nodes"][std::string("n") + std::to_string(i++)] = nodeToDiatom(n);
      }

      treedef["tree"] = super::toDiatom();

      Diatom d;
      d["treeDef"] = treedef;
      return d;
    }

    void fromDiatom(Diatom &d) {
      reset();

      _assert(d.is_table());
      _assert(d["treeDef"].is_table());
      _assert(d["treeDef"]["nodes"].is_table());
      _assert(d["treeDef"]["tree"].is_table());

      Diatom d_tree  = d["treeDef"];
      Diatom d_nodes = d_tree["nodes"];
      Diatom d_gt    = d_tree["tree"];

      nodesFromDiatom(d_nodes);
      super::fromDiatom(d_gt);

      super::walk([&](int i) {
        NodeBase *n = treedef_nodes[i];
        int n_children = nChildren(i);
        ChildLimits limits = n->childLimits();

        if ((limits.min != -1 && n_children < limits.min) || (limits.max != -1 && n_children > limits.max)) {
          throw std::runtime_error(
            std::string("Node of type ") + *n->type +
            std::string(" has invalid # of children (") +
            std::to_string(n_children) + std::string(" for ") +
            std::to_string(limits.min) + std::string("-") + std::to_string(limits.max) +
            std::string(")")
          );
        }
      });
    }

  private:
    std::vector<NodeBase*> treedef_nodes;

    static Diatom nodeToDiatom(NodeBase *n) {
      return diatomize(n->_getSD());
    }

    void nodesFromDiatom(Diatom &d_nodes) {
      // Instantiate into the vector by copying from definitions vector
      _assert(d_nodes.is_table());

      d_nodes.each([&](std::string &key, Diatom &dn) {
        std::string node_type = dn["type"].value__string;

        NodeBase *node = NULL;
        for (auto &n : NodeRegistry::definitions()) {
          if (*n->type == node_type) {
            node = n;
          }
        }

        if (node == NULL) {
          throw std::runtime_error(
            std::string("Couldn't find a node definition called '") + node_type + "'"
          );
        }

        // Clone the node, then deserialize it
        NodeBase *n = node->clone();
        antidiatomize(n->_getSD(), dn);

        treedef_nodes.push_back(n);
      });
    }
  };

}

#endif

