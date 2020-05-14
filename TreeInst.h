/*
 * BT_Inst.h
 *
 * A concrete instance of a Behaviour Tree Definition.
 *  - accessed from user code, provides callbacks to manage the flow
 *    between nodes
 *  - a node may be created as a NodeConcrete created by a NodeDef in the BT_Def
 *  - or it may simply be a function
 *
 * A node ‘runs’ when it is called on to make a decision about tree flow. The possible
 * decisions are:
 *  - return to parent (with SUCCESS or FAILURE)
 *  - cede to a child
 *  - cede to game code until some future time (RUNNING)
 *
 * Game code itself should not have to track individual nodes -- the BT_Inst does so.
 * The user hangs onto a BT_Inst, and calls it when it needs to transition an object
 * between states -- i.e. when it has finished running a state.
 *
 * The BT_Inst will then transition the game to a new state by calling a sequence of
 * nodes, as defined in the BT_Def.
 * 
 */

#ifndef __BT_Inst_h
#define __BT_Inst_h

#include "TreeDef.h"
#include "NodeBase.h"
#include "NodeRegistry.h"

#include <cstdint>
#define __PSA_PSIZE_TYPE uint8_t	// It is highly unlikely our nodes will exceed 256 bytes
#include "PoppableStackAllocator.h"
#include <cassert>

namespace Banyan {

	class TreeInstance {
	public:
		TreeInstance(TreeDefinition *_bt, int _ident) :
			bt(_bt),
			identifier(_ident),
			currentNode_gtInd(-1),
			allocator(128)
		{
			
		}
		~TreeInstance()
		{
			while (stack.size() > 0) popNode();
		}
		
		void begin() {
			currentNode_gtInd = bt->indexOfTopNode();
			assert(currentNode_gtInd >= 0);
			
			pushNode(currentNode_gtInd);
			update();
		}
		
		void update() {
			NodeReturnStatus s = callNode(stack.back());
			update(s);
		}
		
		void update(NodeReturnStatus s) {
			while (s.status != NodeReturnStatus::Running) {
				if (s.status == NodeReturnStatus::Success || s.status == NodeReturnStatus::Failure) {
					popNode();
					if (stack.size() == 0) {
						// printf("Stack size now zero\n");
						// TODO: signal finishing to the user somehow
						break;
					}
					s = stack.back()->resume(identifier, s);
				}
				else if (s.status == NodeReturnStatus::PushChild) {
					pushNode(bt->childOfNode(currentNode_gtInd, s.child));
					s = callNode(stack.back());
				}
			}
		}
		
		void end_running_state(NodeReturnStatus s) {
			popNode();
			update(s);
		}
		
		int stackSize() {
			return (int) stack.size();
		}
		
	private:
		
		TreeDefinition *bt;
		
		int identifier;
		int currentNode_gtInd;	// The index of the node within the GenericTree
		
		StretchyPoppableStackAllocator allocator;
		std::vector<NodeBase*> stack;
			// Nodes are pushed/popped as we descend/ascend the tree
		
		NodeReturnStatus callNode(NodeBase *n) {
			int nChildren = bt->nChildren(currentNode_gtInd);
			return n->call(identifier, nChildren);
		}
		
		void pushNode(int index) {
			currentNode_gtInd = index;
			
			NodeBase *source_node = bt->get(index);
			NodeBase *n = (NodeBase*) allocator.allocate(source_node->size());
			source_node->clone(n);
			
			stack.push_back(n);
		}
		
		void popNode() {
			NodeBase *n = stack.back();
			
			n->~NodeBase();		// Manually call destructor (as placement new used in clone().)
			stack.pop_back();	//  -- i.e. clean up if the node makes any allocations
			allocator.pop();
			
			currentNode_gtInd = bt->parentOfNode(currentNode_gtInd);
			// NB - may be NOT_FOUND -- caller should check & decide what to do
		}

	};

}

#endif
