#include <cstdio>
#include <fstream>
#include <streambuf>
#include <iostream>
#include "_test.h"
#include "../Banyan.hpp"

using namespace Banyan;


// Mocks
// ------------------------------

int MockLeaf__activated;
int MockLeaf__resumed;

Banyan::Node MockLeaf{
  .props = {
    {"succeeds", {.bool_value = false}},
  },
  .activate = [](auto &n) {
    MockLeaf__activated += 1;
    return Ret{
      n.props["succeeds"].bool_value ? Succeeded : Failed,
    };
  },
  .resume = [](auto &n, auto status) {
    MockLeaf__resumed += 1;
    return Ret{Succeeded};
  },
};

int MockFailOnThirdCall__activated;
int MockFailOnThirdCall__resumed;

Node MockFailOnThirdCall{
  .props = {
    {"i", {.int_value = 0}},
  },
  .activate = [](auto &n) {
    if (++MockFailOnThirdCall__activated == 3) {
      return Ret{Failed};
    }
    return Ret{Succeeded};
  },
};

void reset() {
  MockLeaf__activated = 0;
  MockLeaf__resumed = 0;
  MockFailOnThirdCall__activated = 0;
  MockFailOnThirdCall__resumed = 0;
}


// Data
// ------------------------------

#include "test-inverter.hpp"
#include "test-repeater.hpp"
#include "test-selector.hpp"
#include "test-sequence.hpp"
#include "test-succeeder.hpp"
#include "test-while.hpp"


// Tests
// ------------------------------

int main() {
  p_header("Inverter");
  {
    reset();
    Instance bt(&Tree_Inverter, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 1);
    p_assert(MockLeaf__resumed   == 0);
  }


  p_header("Repeater");
  {
    reset();
    Instance bt(&Tree_Repeater, 7459);
    bt.begin();

    p_assert(bt.stack.size()     == 0);
    p_assert(MockLeaf__activated == 6);
    p_assert(MockLeaf__resumed   == 0);
  }


  p_header("Selector");
  {
    reset();
    Instance bt(&Tree_Selector, 7459);
    bt.begin();

    p_assert(bt.stack.size()     == 0);
    p_assert(MockLeaf__activated == 4);
    p_assert(MockLeaf__resumed   == 0);
  }


  p_header("Sequence");
  {
    reset();
    Instance bt(&Tree_Sequence, 7459);
    bt.begin();

    p_assert(bt.stack.size()     == 0);
    p_assert(MockLeaf__activated == 5);
    p_assert(MockLeaf__resumed   == 0);
  }


  p_header("Succeeder");
  {
    reset();
    Instance bt(&Tree_Succeeder, 7459);
    bt.begin();

    p_assert(bt.stack.size()     == 0);
    p_assert(MockLeaf__activated == 2);
    p_assert(MockLeaf__resumed   == 0);
  }


  p_header("While");
  {
    reset();
    Instance bt(&Tree_While, 7459);
    bt.begin();

    p_assert(bt.stack.size()                == 0);
    p_assert(MockLeaf__activated            == 2);
    p_assert(MockFailOnThirdCall__activated == 3);
  }


  return 0;
}

