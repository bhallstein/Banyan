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
#include "GenericTree/GenericTree.h"

#include "src/Node_Repeater.h"
#include "src/Node_Inverter.h"
#include "src/Node_Succeeder.h"
#include "src/Node_Sequence.h"
#include "src/Node_Selector.h"
#include "src/Node_While.h"

#include <stdexcept>

namespace Banyan {

  class TreeDefinition : public GenericTree<NodeBase> {
    typedef GenericTree<NodeBase> super;

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

      treedef["tree"] = super::toDiatom(treedef_nodes);

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
      super::fromDiatom(d_gt, treedef_nodes);

      super::walk([&](NodeBase *n, int i) {
        int n_children = nChildren(i);
        ChildLimits limits = n->childLimits();

        if ((limits.min != -1 && n_children < limits.min) || (limits.max != -1 && n_children > limits.max))
          throw std::runtime_error(
            std::string("Node of type ") + *n->type +
            std::string(" has invalid # of children (") +
            std::to_string(n_children) + std::string(" for ") +
            std::to_string(limits.min) + std::string("-") + std::to_string(limits.max) +
            std::string(")")
          );
      });
    }

  private:
    std::vector<NodeBase*> treedef_nodes;

    static Diatom nodeToDiatom(NodeBase *n) {
      return diatomize(n->_getSD());
    }

    void nodesFromDiatom(Diatom &d_nodes) {
      // For each node, instantiate into the vector by copying from the definitions
      // vector, using the identifier

      _assert(d_nodes.is_table());

      d_nodes.each([&](std::string &key, Diatom &dn) {
        std::string identifier = dn["type"].value__string;

        // Find existing NodeDef with the right identifier
        NodeRegistry::Wrapper *nw_def = NULL;
        for (auto &nw : NodeRegistry::definitions()) {
          if (nw->identifier == identifier) {
            nw_def = nw;
          }
        }

        if (nw_def == NULL) {
          throw std::runtime_error(
            std::string("Couldn't find a node definition called '") + identifier + "'"
          );
        }

        // Clone the node, then deserialize it
        NodeBase *n = nw_def->node->clone();
        antidiatomize(n->_getSD(), dn);

        treedef_nodes.push_back(n);
      });
    }
  };

}

#endif

