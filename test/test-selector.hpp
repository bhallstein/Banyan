#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSelector() {
  return Selector(
    {
      {"i", {.int_value = 3}},
    },
    {
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(true),
      MockLeaf(false),
    }
  );
}
