#ifndef __NodeBase_h
#define __NodeBase_h

#include <new>
#include <stdexcept>
#include "../GenericTree/Diatom/Diatomize/Diatomize.h"


namespace Banyan {

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


  struct ChildLimits {
    int min, max;
  };


  typedef NodeReturnStatus (node_function)(size_t identifier);


  class NodeBase {
  public:
    virtual ~NodeBase() {  }

    virtual ChildLimits childLimits() = 0;
    Diatomize::Descriptor _getSD() {
      Diatomize::Descriptor sd = getSD();
      sd.descriptor.push_back(diatomPart("type", &type));

      for (auto i : __getSD().descriptor) {
        sd.descriptor.push_back(i->clone());
      }

      return sd;
    }
    virtual Diatomize::Descriptor __getSD() { return {{ }}; }

    virtual NodeReturnStatus call(int identifier, int nChildren) = 0;
    virtual NodeReturnStatus resume(int identifier, NodeReturnStatus &s) = 0;

    virtual NodeBase* clone(void *into = NULL) = 0;
    virtual int size() = 0;

    std::string *type;

  protected:
    virtual Diatomize::Descriptor getSD() { return { }; }
  };


  template<class Derived>
  class NodeBase_CRTP : public NodeBase {
  public:
    NodeBase* clone(void *mem = NULL) {
      NodeBase *n;
      if (mem) { n = new (mem) Derived((Derived const &) (*this)); }
      else     { n = new Derived((Derived const &) (*this)); }
      n->type = type;
      return n;
    }

    int size() { return sizeof(Derived); }
      // CRTP superclass
      // - Calling clone() on a subclass will invoke this method, calling the
      //   subclass’s copy constructor.
      // - Especially for classes with automatically-generated copy constructors,
      //   this is super convenient.
  };


  class NodeFunctional : public NodeBase_CRTP<NodeFunctional> {
  public:
    ChildLimits childLimits() { return { 0, 0}; }
    Diatomize::Descriptor getSD() {
      return Diatomize::Descriptor();
    }

    NodeReturnStatus call(int identifier, int nChildren) {
      return f(identifier);
    }

    NodeReturnStatus resume(int identifier, NodeReturnStatus &s) {
      throw std::runtime_error("resume() called on functional node");
      return s;
    }

    node_function *f;
  };

}


#define STBL(s) diatomPart(#s, &s)
#define STBL1(s)                  STBL(s)
#define STBL2(s1, s2)             STBL(s1), STBL(s2)
#define STBL3(s1, s2, s3)         STBL(s1), STBL(s2), STBL(s3)
#define STBL4(s1, s2, s3, s4)     STBL(s1), STBL(s2), STBL(s3), STBL(s4)
#define STBL5(s1, s2, s3, s4, s5) STBL(s1), STBL(s2), STBL(s3), STBL(s4), STBL(s5)

#define GET_STBL_MACRO(_1, _2, _3, _4, _5, NAME, ...) NAME

#define SETTABLES(...) \
    Diatomize::Descriptor __getSD() {  \
    return {{ GET_STBL_MACRO(__VA_ARGS__, STBL5, STBL4, STBL3, STBL2, STBL1)(__VA_ARGS__) }};  \
  }

// NB Macros are arguably not the right tool for this. May be possible with templates.
//    But, this is nice and simple.

#endif

