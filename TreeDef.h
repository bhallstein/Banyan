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

	class TreeDefinition : public GenericTree<NodeRegistry::Wrapper> {
		
		typedef GenericTree<NodeRegistry::Wrapper> super;
		
		std::vector<NodeRegistry::Wrapper*> treedef_nodes;
		
		
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
				NODE_DEFINITION(Repeater, Repeater);	// Decorators
				NODE_DEFINITION(Inverter, Inverter);
				NODE_DEFINITION(Succeeder, Succeeder);
			
				NODE_DEFINITION(Sequence, Sequence);	// Composites
				NODE_DEFINITION(Selector, Selector);
				NODE_DEFINITION(While, While);
			}
			return (loaded = true);
		}
		
		/*** Serialization ***/
	
		// The serialized form of the TreeDef is like so:
		//    nodes => { node, node, node },
		//    tree => [generictree serialized form]
		
		Diatom toDiatom() {
			Diatom d;
			
			d["nodes"] = Diatom();
			int i = 0;
			for (auto &n : treedef_nodes)
				d["nodes"][std::string("n") + std::to_string(i++)] = nodeToDiatom(n);
			
			d["tree"] = super::toDiatom(treedef_nodes);
			
			return d;
		}
		
		void fromDiatom(Diatom &d_tree) {
			_assert(d_tree.isTable());
			reset();
			
			Diatom d_nodes = d_tree["nodes"];
			Diatom d_gt    = d_tree["tree"];
			
			_assert(d_nodes.isTable());
			_assert(d_gt.isTable());
			
			treedef_nodes = _nodesFromDiatom(d_nodes);
			super::fromDiatom(d_gt, treedef_nodes);
			
			/*
			Check child limits?
			super::walk([&filename](NodeRegistry::Wrapper *ndw, int i) {
				if (ndw->type == NodeType::Function)
					return;

				int n_children = nChildren(i);
				ChildLimits limits = ndw->nodeDef->childLimits();

				if ((limits.min != -1 && n_children < limits.min) ||
					(limits.max != -1 && n_children > limits.max))
					_bnyn_throw(
						(std::string("Node of type ") + ndw->identifier +
						 std::string(" in file '") + std::string(filename) + std::string("'") +
						 std::string(" has invalid # of children")
						).c_str()
					);
			});
			*/
		}
		
	private:
		static Diatom
		nodeToDiatom(NodeRegistry::Wrapper *nw) {
			Diatom d;
			
			d = diatomize(*nw->node, nw->node->getSD());
			d["type"] = nw->identifier;
			
			return d;
		}
		
		static std::vector<NodeRegistry::Wrapper*>
		_nodesFromDiatom(Diatom &d_nodes) {
			// For each node, instantiate into the vector by copying from the definitions
			// vector, using the identifier
			std::vector<NodeRegistry::Wrapper*> _nodes;
			
			_assert(d_nodes.isTable());
			
			for (auto &entry : d_nodes.descendants()) {
				Diatom &dn = entry.second;
				
				Diatom d_identifier = dn["type"];
				std::string identifier = d_identifier.str_value();
				
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
				NodeRegistry::Wrapper *nw_new = new NodeRegistry::Wrapper(
					nw_def->node->clone(), nw_def->identifier
				);
				antidiatomize(*nw_new->node, nw_new->node->getSD(), dn);
				
				_nodes.push_back(nw_new);
			}

			return _nodes;
		}
		
	};
	
}

#endif
