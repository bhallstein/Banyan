#include "Banyan.hpp"
#include "mocks.hpp"

Node TestWhile() {
  return While(
    {
      MockFailOnThirdCall(),
      MockLeaf(false),
    }
  );
}
