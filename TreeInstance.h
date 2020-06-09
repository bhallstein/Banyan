//
// TreeInstance.h
//
// A concrete instance of a behaviour tree definition.
//  - provides callbacks to manage the flow between nodes
//  - a node may be created as a NodeConcrete created by a NodeDef in the TreeDefinition
//    or it may simply be a function
//
// A node 'runs' when it is called on to make a decision about tree flow. The possible
// decisions are:
//  - SUCCESS or FAILURE: return to parent
//  - cede to a child
//  - RUNNING: cede to game code until some time in the future
//
// Game code itself shouldn't track individual nodes -- the TreeInstance does this.
// The user hangs onto a TreeInstance, and calls it when it has finished running a state
// to transition it into a new state.
//
// The TreeInstance transitions to a new state by calling a sequence of nodes
// as defined in the TreeDefinition.
//

#ifndef __BT_Inst_h
#define __BT_Inst_h

#include "TreeDefinition.h"
#include "src/NodeBase.h"
#include "src/NodeRegistry.h"

#include <cstdint>
#define __PSA_PSIZE_TYPE uint8_t  // It is highly unlikely our nodes will exceed 256 bytes
#include "StackAllocators/StackAllocator_PopAndExpand.h"

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
          pushNode(bt->indexForChild(currentNode_gtInd, s.child));
          s = callNode(stack.back());
        }
      }
    }

    void end_running_state(NodeReturnStatus s) {
//      popNode();
      update(s);
    }

    int stackSize() {
      return (int) stack.size();
    }

  private:

    TreeDefinition *bt;

    int identifier;
    int currentNode_gtInd;  // The index of the node within the GenericTree

    StackAllocator_PopAndExpand allocator;
    std::vector<NodeBase*> stack;
      // Nodes are pushed/popped as we descend/ascend the tree

    NodeReturnStatus callNode(NodeBase *n) {
      int nChildren = bt->nChildren(currentNode_gtInd);
      return n->call(identifier, nChildren);
    }

    void pushNode(int index) {
      currentNode_gtInd = index;

      NodeBase *source_node = bt->getNode(index);
      NodeBase *n = (NodeBase*) allocator.allocate(source_node->size());
      source_node->clone(n);

      stack.push_back(n);
    }

    void popNode() {
      NodeBase *n = stack.back();

      n->~NodeBase();    // Manually call destructor (as placement new used in clone().)
      stack.pop_back();  //  -- i.e. clean up if the node makes any allocations
      allocator.pop();

      currentNode_gtInd = bt->parentIndex(currentNode_gtInd);
      // NB - may be NOT_FOUND -- caller should check & decide what to do
    }

  };

}

#endif

