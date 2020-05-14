/*
 * BT_Def.h
 *
 * A behaviour tree definition
 *  - a tree of NodeDef instances
 *  - de-/serialization
 *  - create instances (BT_Inst) to attach to a game entity
 * 
 */

#ifndef __BT_Def_h
#define __BT_Def_h

#include "LuaObj.h"
#include "NodeDefinition.h"

#define _GT_ENABLE_SERIALIZATION
#include "GenericTree.h"

#include "Node_Repeater.h"
#include "Node_Inverter.h"
#include "Node_Succeeder.h"
#include "Node_Sequence.h"
#include "Node_Selector.h"
#include "Node_While.h"

#include "lua.hpp"

#include <stdexcept>

namespace Banyan {

	class TreeDefinition {
	public:
		
		TreeDefinition(const char *filename)
		{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wunused-variable"
			static bool built_ins_loaded = loadBuiltIns();
			#pragma clang diagnostic pop
			
			LuaObj l_nodes(filename, "nodes");
			LuaObj l_tree(filename, "tree");
			
			nodes = deserializeNodes(l_nodes, filename);
			t = _deserializeTree(l_tree, nodes, filename);
		}
		
		TreeDefinition(lua_State *L)
		{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wunused-variable"
			static bool built_ins_loaded = loadBuiltIns();
			#pragma clang diagnostic pop
			
			lua_getglobal(L, "nodes");  LuaObj l_nodes(L);  lua_pop(L, 1);
			lua_getglobal(L, "tree");   LuaObj l_tree(L);   lua_pop(L, 1);
			
			nodes = deserializeNodes(l_nodes, "[from luaobj]");
			t = _deserializeTree(l_tree, nodes, "[from luaobj]");
		}
		
		bool isEmpty() {
			return t.isEmpty();
		}
		
		int indexOfParent_ForNode(int index_in_gt) {
			return t.parentOfNode(index_in_gt);
		}
		int nChildren_ForNode(int node) {
			return t.nChildren(node);
		}
		int indexOfChild_ForNode(int node, int child) {
			return t.childOfNode(node, child);
		}
		NodeDef::Wrapper* nodeDefWrapper_ForNode(int index_in_gt) {
			return t.get(index_in_gt);
		}
		
		static bool loadBuiltIns() {
			NODE_DEFINITION(Repeater, Repeater::Def);
			NODE_DEFINITION(Inverter, Inverter::Def);
			NODE_DEFINITION(Succeeder, Succeeder::Def);
			
			NODE_DEFINITION(Sequence, Sequence::Def);
			NODE_DEFINITION(Selector, Selector::Def);
			NODE_DEFINITION(While, While::Def);
			
			return true;
		}
		
		/* Serialization */
		
		std::string serialize() {
			std::string s;
			
			s += "nodes = {\n";
			for (auto &n : nodes) {
				s += serializeNode(n);
			}
			s += "}\n\n";
			
			s += std::string("tree = ") + serializeTree(t, nodes);
			
			return LuaObj::reindentString(s);
		}
		
		std::string serializeNode(NodeDef::Wrapper *ndw) {
			std::string s;
			
			s += "{\n";
			s += std::string("type = \"") + ndw->identifier + std::string("\",\n");
			s += ndw->nodeDef->serialize();
			s += "},\n";

			return s;
		}
		
		static GenericTree<NodeDef::Wrapper>
		_deserializeTree(LuaObj &l_tree, std::vector<NodeDef::Wrapper*> &nodes, const char *filename) {
			if (!l_tree.isTable())
				_bnyn_throw(
					(std::string("\"tree\" not found in BT_Def file '") +
					std::string(filename) + "'").c_str()
				);
			
			auto t = deserializeTree(l_tree, nodes);
			
			t.walk([&t, &filename](NodeDef::Wrapper *ndw, int i) {
				if (ndw->type == NodeDef::Type::Function)
					return;
				
				int n_children = t.nChildren(i);
				NodeDef::ChildLimits limits = ndw->nodeDef->childLimits();
				
				if ((limits.min != -1 && n_children < limits.min) ||
					(limits.max != -1 && n_children > limits.max))
					_bnyn_throw(
						(std::string("Node of type ") + ndw->identifier +
						 std::string(" in file '") + std::string(filename) + std::string("'") +
						 std::string(" has invalid # of children")
						).c_str()
					);
			});
			
			return t;
		}
		
		static std::vector<NodeDef::Wrapper*>
		deserializeNodes(LuaObj &l_nodes, const char *filename) {
			// For each node, instantiate into the vector by copying from the definitions
			// vector, using the identifier
			std::vector<NodeDef::Wrapper*> _nodes;
			
			if (!l_nodes.isTable())
				throw std::runtime_error(
					(std::string("\"nodes\" not found in BT_Def file '") +
					std::string(filename) + "'").c_str()
				);
			
			for (auto &entry : l_nodes.descendants()) {
				LuaObj &l_node = entry.second;
				
				std::string identifier = l_node["type"].str_value();
				
				// Find existing NodeDef with the right identifier
				NodeDef::Wrapper *ndw_def = NULL;
				auto &defs = NodeDef::definitions();
				for (auto &ndw : defs)
					if (ndw.identifier.compare(identifier) == 0)
						ndw_def = &ndw;
				
				if (ndw_def == NULL)
					throw std::runtime_error(
						(std::string("Couldn't find a node definition called '") +
						identifier + "'").c_str()
					);
				
				// If the node is class-type, clone it, then deserialize it
				NodeDef::Wrapper *ndw_new;
				if (ndw_def->type == NodeDef::Type::Class) {
					ndw_new = new NodeDef::Wrapper(
						ndw_def->nodeDef->clone(), ndw_def->identifier, ndw_def->symbol
					);
					ndw_new->nodeDef->deserialize(l_node);
				}
				// If function-type, just copy it
				else
					ndw_new = ndw_def;
				
				_nodes.push_back(ndw_new);
			}
			
			return _nodes;
		}
		
		std::vector<NodeDef::Wrapper*> nodes;
		GenericTree<NodeDef::Wrapper> t;

	};
	
}

#endif 

