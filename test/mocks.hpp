#ifndef MocksH
#define MocksH
#include "Banyan.hpp"

using namespace Banyan;


// MockLeaf
// ------------------------------------

extern int MockLeaf__activated;
extern int MockLeaf__resumed;

inline Ret mockleaf_activate(RunNode& rn, size_t e) {
  MockLeaf__activated += 1;
  return Ret{
    rn.props["succeeds"].bool_value ? Succeeded : Failed,
  };
}
inline Ret mockleaf_resume(RunNode& node, size_t identifier, ReturnStatus status) {
  MockLeaf__resumed += 1;
  return Ret{Succeeded};
}

inline Node MockLeaf(bool succeeds) {
  static NodeType MockLeafType{
    "MockLeaf",
    mockleaf_activate,
    mockleaf_resume,
    0,
    0,
    {
      {"succeeds", {.bool_value = succeeds}},
    }
  };
  return mk_node(MockLeafType);
}


// MockFailOnThirdCall
// ------------------------------------

extern int MockFailOnThirdCall__activated;
extern int MockFailOnThirdCall__resumed;

inline Ret mlfotc_activate(RunNode& rn, size_t e) {
  if (++MockFailOnThirdCall__activated == 3) {
    return Ret{Failed};
  }
  return Ret{Succeeded};
}

inline Node MockFailOnThirdCall() {
  static NodeType Type{
    "MockFailOnThirdCall",
    mlfotc_activate,
    default_resume_func,
    0,
    0,
    {{"i", {.int_value = 0}}},
  };
  return mk_node(Type);
}


void reset() {
  MockLeaf__activated            = 0;
  MockLeaf__resumed              = 0;
  MockFailOnThirdCall__activated = 0;
  MockFailOnThirdCall__resumed   = 0;
}

#endif
