#include "Banyan.hpp"
#include "mocks.hpp"

Node TestRepeater() {
  return Repeater(
    RepeaterN(3),
    RepeaterBreakOnFailure(true),
    {
      Repeater(
        RepeaterN(2),
        RepeaterBreakOnFailure(false),
        {
          MockLeaf(MockLeafSucceeds(false)),
        }
      ),
    }
  );
}
