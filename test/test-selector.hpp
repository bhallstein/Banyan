#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSelector() {
  return Selector(
    SelectorBreakOn1stSuccess(true),
    SelectorRandomizeOrder(false),
    {
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(true),
      MockLeaf(false),
    }
  );
}
