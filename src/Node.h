#ifndef __Banyan_Node_h
#define __Banyan_Node_h

#include <new>
#include <stdexcept>
#include "../GenericTree/Diatom/DiatomSerialization.h"


namespace Banyan {

  // NodeReturnStatus
  // -----------------------------------

  struct NodeReturnStatus {
    enum T {
      Success,
      Failure,
      Running,
      PushChild
    };
    T status;
    int child;

    static NodeReturnStatus invert(const NodeReturnStatus &s) {
      return (NodeReturnStatus) { s.status == Success ? Failure : Success };
    }
  };


  // node_function
  // -----------------------------------

  typedef NodeReturnStatus (node_function)(size_t identifier);


  // ChildLimits
  // -----------------------------------

  struct ChildLimits {
    int min, max;
  };


  // NodeSuper - base node
  // -----------------------------------

  struct NodeSuper {
    virtual ~NodeSuper() {  }

    virtual ChildLimits childLimits() = 0;

    virtual NodeReturnStatus activate(int identifier, int nChildren) = 0;
    virtual NodeReturnStatus resume(int identifier, NodeReturnStatus &s) = 0;

    virtual NodeSuper* clone(void *into = NULL) = 0;
    virtual int size() = 0;
    virtual std::string type() = 0;

    std::vector<std::string> state_contexts;

    virtual Diatom to_diatom() { return { }; }
    virtual void from_diatom(Diatom d) { }
    Diatom __to_diatom() {
      Diatom d;
      auto child_props = to_diatom();

      d["type"] = type();
      d["state_contexts"] = Diatom();

      for (int i=0; i < state_contexts.size(); ++i) {
        d["state_contexts"][std::string("n") + std::to_string(i)] = state_contexts[i];
      }

      child_props.each([&](std::string key, Diatom value) {
        d[key] = value;
      });

      return d;
    }
    void __from_diatom(Diatom d) {
      d["state_contexts"].each([&](std::string key, Diatom item_name) {
        state_contexts.push_back(item_name.string_value);
      });
      from_diatom(d);
    }
  };


  // Node
  // -----------------------------------
  // - Class for extending by custom node classes
  // - Uses CRTP for automatic cloning, sizing

  template<class Derived>
  struct Node : NodeSuper {
    NodeSuper* clone(void *mem = NULL) {
      if (mem) { return new (mem) Derived((Derived const &) (*this)); }
      else     { return new Derived((Derived const &) (*this)); }
    }

    int size() { return sizeof(Derived); }
      // CRTP superclass
      // - Calling clone() on a subclass will invoke this method, calling the
      //   subclass’s copy constructor.
      // - Especially for classes with automatically-generated copy constructors,
      //   this is super convenient.
  };


  // NodeFunctional
  // -----------------------------------
  // - User node_functions are converted to NodeFunctionals

  struct NodeFunctional : Node<NodeFunctional> {
    ChildLimits childLimits() { return { 0, 0 }; }

    std::string functional_node_type;
    std::string type() {
      return functional_node_type;
    }

    NodeReturnStatus activate(int identifier, int nChildren) {
      return f(identifier);
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      throw std::runtime_error("resume() called on functional node");
      return s;
    }

    node_function *f;
  };

}


#endif

