#include "Banyan.hpp"
#include "mocks.hpp"

Node TestRepeater() {
  return Repeater(
    {
      {"n", {.int_value = 3}},
      {"break_on_failure", {.bool_value = true}},
    },
    {
      Repeater(
        {
          {"n", {.int_value = 2}},
        },
        {MockLeaf(true)}
      ),
    }
  );
}
