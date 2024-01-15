#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSequence() {
  return Sequence(
    {
      {"break_on_failure", {.bool_value = false}},
    },
    {
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
    }
  );
}
