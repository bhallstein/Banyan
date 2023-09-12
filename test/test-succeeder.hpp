#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSucceeder() {
  return Repeater(
    RepeaterN(2),
    RepeaterBreakOnFailure(true),
    {
      Succeeder(
        {MockLeaf(MockLeafSucceeds(false))}
      ),
    }
  );
}
