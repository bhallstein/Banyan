#ifndef MocksH
#define MocksH
#include "Banyan.hpp"

using namespace Banyan;

extern int MockLeaf__activated;
extern int MockLeaf__resumed;

typedef bool      TMockLeafSucceeds;
TMockLeafSucceeds MockLeafSucceeds(bool succeeds) { return succeeds; }

inline Node MockLeaf(TMockLeafSucceeds succeeds) {
  return {
    .props = {
      {"succeeds", {.bool_value = succeeds}},
    },
    .activate = [](size_t e, auto& n) {
      MockLeaf__activated += 1;
      return Ret{
        n.props["succeeds"].bool_value ? Succeeded : Failed,
      }; },
    .resume   = [](size_t e, auto& n, auto status) {
      MockLeaf__resumed += 1;
      return Ret{Succeeded}; },
  };
}


extern int MockFailOnThirdCall__activated;
extern int MockFailOnThirdCall__resumed;

inline Node MockFailOnThirdCall() {
  return {
    .props = {
      {"i", {.int_value = 0}},
    },
    .activate = [](size_t e, auto& n) {
      if (++MockFailOnThirdCall__activated == 3) {
        return Ret{Failed};
      }
      return Ret{Succeeded};
    },
  };
}


void reset() {
  MockLeaf__activated            = 0;
  MockLeaf__resumed              = 0;
  MockFailOnThirdCall__activated = 0;
  MockFailOnThirdCall__resumed   = 0;
}

#endif
