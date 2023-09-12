#include <cstdio>
#include <fstream>
#include <iostream>
#include <streambuf>

#include "../Banyan.hpp"
#include "_test.hpp"

using namespace Banyan;

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
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Repeater");
  {
    reset();
    Instance bt(&Tree_Repeater, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 6);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Selector");
  {
    reset();
    Instance bt(&Tree_Selector, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 4);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Sequence");
  {
    reset();
    Instance bt(&Tree_Sequence, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 5);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Succeeder");
  {
    reset();
    Instance bt(&Tree_Succeeder, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 2);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("While");
  {
    reset();
    Instance bt(&Tree_While, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 2);
    p_assert(MockFailOnThirdCall__activated == 3);
  }


  return 0;
}
