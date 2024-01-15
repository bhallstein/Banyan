#include "Banyan.hpp"
#include "mocks.hpp"

Node TestSucceeder() {
  return Repeater(
    {
      {"n", {.int_value = 2}},
      {"break_on_failure", {.bool_value = true}},
    },
    {
      Succeeder(
        {MockLeaf(false)}
      ),
    }
  );
}
