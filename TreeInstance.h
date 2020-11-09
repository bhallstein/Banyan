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
// The user hangs onto a TreeInstance, calling it when it has finished running a node
// to transition to a new node.
//
// The TreeInstance transitions through tree of nodes, as defined in the TreeDefinition,
// coming to rest on some other node.
//

#ifndef __Banyan_TreeInstance_h
#define __Banyan_TreeInstance_h

#include "TreeDefinition.h"
#include "src/NodeRegistry.h"

#include <cstdint>
#define __PSA_PSIZE_TYPE uint8_t  // It is highly unlikely our nodes will exceed 256 bytes
#include "StackAllocators/StackAllocator_PopAndExpand.h"


namespace Banyan {

  class TreeInstance {
  public:
    TreeInstance(TreeDefinition *_tree_def, int _identifier) :
      tree_def(_tree_def),
      identifier(_identifier),
      index__current_node_in_gt(-1),
      allocator(128)
    {

    }
    ~TreeInstance()
    {
      while (node_stack.size() > 0) {
        popNode();
      }
    }


    void begin() {
      index__current_node_in_gt = tree_def->indexOfTopNode();

      pushNode(index__current_node_in_gt);
      update(callNode(node_stack.back()));
    }

    void update(NodeReturnStatus s) {
      while (s.status != NodeReturnStatus::Running) {
        if (s.status == NodeReturnStatus::Success || s.status == NodeReturnStatus::Failure) {
          popNode();
          if (node_stack.size() == 0) {
            // printf("Stack size now zero\n");
            // TODO: signal finishing to the user somehow
            break;
          }
          s = node_stack.back()->resume(identifier, s);
        }
        else if (s.status == NodeReturnStatus::PushChild) {
          pushNode(tree_def->indexForChild(index__current_node_in_gt, s.child));
          s = callNode(node_stack.back());
        }
      }
    }

    void end_running_node(NodeReturnStatus s) {
      update(s);
    }

    int stackSize() {
      return (int) node_stack.size();
    }

  private:
    TreeDefinition *tree_def;

    int identifier;      // External identifier of the entity that this behaviour tree belongs to
    int index__current_node_in_gt;

    StackAllocator_PopAndExpand allocator;
    std::vector<NodeSuper*> node_stack;

    NodeReturnStatus callNode(NodeSuper *n) {
      int nChildren = tree_def->nChildren(index__current_node_in_gt);
      return n->call(identifier, nChildren);
    }

    void pushNode(int index) {
      index__current_node_in_gt = index;

      NodeSuper *source_node = tree_def->getNode(index);
      NodeSuper *n = (NodeSuper*) allocator.allocate(source_node->size());
      source_node->clone(n);

      node_stack.push_back(n);
    }

    void popNode() {
      NodeSuper *n = node_stack.back();

      n->~NodeSuper();        // Manually call destructor (as placement new used in clone())
      node_stack.pop_back();  // -- i.e. clean up if the node makes any allocations
      allocator.pop();

      index__current_node_in_gt = tree_def->parentIndex(index__current_node_in_gt);
      // NB - may be NOT_FOUND -- caller should check & decide what to do
    }
  };

}

#endif

