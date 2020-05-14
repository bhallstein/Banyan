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

#include "BT_Def.h"
#include "NodeDefinition.h"
#include <cassert>

class BT_Inst {
public:
	BT_Inst(BT_Def *_bt, int _ident) :
		bt(_bt),
		identifier(_ident),
		currentNode_gtInd(-1)
	{
		
	}
	
	void begin() {
		currentNode_gtInd = bt->t.indexOfTopNode();
		assert(currentNode_gtInd >= 0);
		
		pushNode(currentNode_gtInd);
		update();
	}
	
	void update() {
		BehaviourStatus s = callNode(stack.back());
		update(s);
	}
	
	void update(BehaviourStatus s) {
		while (s.status != NodeReturnStatus::Running) {
			if (s.status == NodeReturnStatus::Success || s.status == NodeReturnStatus::Failure) {
				popNode();
				if (stack.size() == 0) {
					// printf("Stack size now zero\n");
					// TODO: signal finishing to the user somehow
					break;
				}
				s = stack.back().nc
					->resume(identifier, s);
			}
			else if (s.status == NodeReturnStatus::PushChild) {
				pushNode(bt->indexOfChild_ForNode(currentNode_gtInd, s.child));
				s = callNode(stack.back());
			}
		}
	}
	
	void end_running_state(BehaviourStatus s) {
		popNode();
		update(s);
	}
	
	int stackSize() {
		return (int) stack.size();
	}
	
private:
	
	BT_Def *bt;
	
	int identifier;
	int currentNode_gtInd;	// The index of the node within the GenericTree
	
	std::vector<NodeConcrete::Wrapper> stack;
		// Nodes are pushed/popped as we descend/ascend the tree
	
	BehaviourStatus callNode(NodeConcrete::Wrapper &ncw) {
		int nChildren = bt->nChildren_ForNode(currentNode_gtInd);
		
		if (ncw.type == NodeDef::Type::Class) {
			NodeConcrete *nc = ncw.nc;
			return nc->call(identifier, nChildren);
		}
		else {
			NodeDef::node_function *f = ncw.nf;
			return f(identifier, nChildren);
		}
	}
	
	void pushNode(int index) {
		currentNode_gtInd = index;
		
		NodeDef::Wrapper *ndw = bt->nodeDefWrapper_ForNode(index);
		
		NodeConcrete::Wrapper ncw;
		ncw.type = ndw->type;

		if (ndw->type == NodeDef::Type::Class)
			ncw.nc = ndw->nodeDef->concreteFactory();
		else
			ncw.nf = ndw->nodeFn;
		
		stack.push_back(ncw);
	}
	
	void popNode() {
		NodeConcrete::Wrapper ncw = stack.back();
		stack.pop_back();
		
		if (ncw.type == NodeDef::Type::Class)
			delete ncw.nc;
		
		currentNode_gtInd = bt->indexOfParent_ForNode(currentNode_gtInd);
		// NB - may be NOT_FOUND -- caller should check & decide what to do
	}

};


#endif
