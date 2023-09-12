#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSequence() {
  return Sequence(
    SequenceBreakOnFailure(false),
    {
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
      MockLeaf(false),
    }
  );
}
