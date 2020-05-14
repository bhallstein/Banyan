/*
 * TreeDefinition.h
 *
 * A TreeDefinition is shared among many TreeInstances, which use it to create
 * nodes when required, by copying them from those in the TreeDefinition.
 * 
 * This means the entire tree does not have to be duplicated for every instance,
 * which can instead maintain only a stack of current nodes.
 *
 */

#ifndef __TreeDef_h
#define __TreeDef_h

#include "NodeBase.h"
#include "NodeRegistry.h"

#define _GT_ENABLE_SERIALIZATION
#include "GenericTree.h"

#include "Node_Repeater.h"
#include "Node_Inverter.h"
#include "Node_Succeeder.h"
#include "Node_Sequence.h"
#include "Node_Selector.h"
#include "Node_While.h"

#include <stdexcept>

namespace Banyan {

	class TreeDefinition : public GenericTree<NodeBase> {
		typedef GenericTree<NodeBase> super;
		
	public:
		
		TreeDefinition() { registerBuiltins(); }
		~TreeDefinition() { reset(); }
		
		void reset() {
			for (auto &i : treedef_nodes)
				delete i;
			treedef_nodes.clear();
			super::reset();
		}
		
		static bool registerBuiltins() {
			static bool loaded = false;
			if (!loaded) {
				NODE_DEFINITION(Repeater, Repeater); // Decorators
				NODE_DEFINITION(Inverter, Inverter);
				NODE_DEFINITION(Succeeder, Succeeder);
			
				NODE_DEFINITION(Sequence, Sequence);	 // Composites
				NODE_DEFINITION(Selector, Selector);
				NODE_DEFINITION(While, While);
			}
			return (loaded = true);
		}
		
		/*** Serialization ***/
	
		// The serialized form of the TreeDef is like so:
		//    treedef:
		//       nodes: { node, node, node },
		//       tree:  [generictree serialized form]
		
		Diatom toDiatom() {
			Diatom d;
			
			d["nodes"] = Diatom();
			int i = 0;
			for (auto &n : treedef_nodes)
				d["nodes"][std::string("n") + std::to_string(i++)] = nodeToDiatom(n);
			
			d["tree"] = super::toDiatom(treedef_nodes);
			
			return d;
		}
		
		void fromDiatom(Diatom &d) {
			using Str = std::string;
			
			reset();
			
			_assert(d.isTable());
			
			Diatom d_tree  = d["treeDef"];
			_assert(d_tree.isTable());
			
			Diatom d_nodes = d_tree["nodes"];
			Diatom d_gt    = d_tree["tree"];
			
			_assert(d_nodes.isTable());
			_assert(d_gt.isTable());
			
			nodesFromDiatom(d_nodes);
			super::fromDiatom(d_gt, treedef_nodes);
			
			super::walk([&](NodeBase *n, int i) {
				int n_children = nChildren(i);
				ChildLimits limits = n->childLimits();

				if ((limits.min != -1 && n_children < limits.min) || (limits.max != -1 && n_children > limits.max))
					throw std::runtime_error(
						Str("Node of type ") + *n->type +
						 Str(" has invalid # of children (") +
						 std::to_string(n_children) + Str(" for ") +
						 std::to_string(limits.min) + Str("-") + std::to_string(limits.max) +
						 Str(")")
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
			
			_assert(d_nodes.isTable());
			
			for (auto &entry : d_nodes.descendants()) {
				Diatom &dn = entry.second;
				
				std::string identifier = dn["type"].str_value();
				
				// Find existing NodeDef with the right identifier
				NodeRegistry::Wrapper *nw_def = NULL;
				for (auto &nw : NodeRegistry::definitions())
					if (nw->identifier == identifier)
						nw_def = nw;
				
				if (nw_def == NULL)
					throw std::runtime_error(
						std::string("Couldn't find a node definition called '") + identifier + "'"
					);
				
				// Clone the node, then deserialize it
				NodeBase *n = nw_def->node->clone();
				antidiatomize(n->_getSD(), dn);
				
				treedef_nodes.push_back(n);
			}
		}
		
	};
	
}

#endif
