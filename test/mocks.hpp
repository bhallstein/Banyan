#include "../Banyan.hpp"

// Mocks
// ------------------------------

extern int MockLeaf__activated;
extern int MockLeaf__resumed;

Banyan::Node MockLeaf{
  .props = {
    {"succeeds", {.bool_value = false}},
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

int MockFailOnThirdCall__activated;
int MockFailOnThirdCall__resumed;

Node MockFailOnThirdCall{
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

void reset() {
  MockLeaf__activated            = 0;
  MockLeaf__resumed              = 0;
  MockFailOnThirdCall__activated = 0;
  MockFailOnThirdCall__resumed   = 0;
}
