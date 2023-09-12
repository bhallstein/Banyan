#include <cstdio>
#include <fstream>
#include <iostream>
#include <streambuf>

#include "../Banyan.hpp"
#include "_test.hpp"


// Data
// ------------------------------

#include "mocks.hpp"
#include "test-inverter.hpp"
#include "test-repeater.hpp"
#include "test-selector.hpp"
#include "test-sequence.hpp"
#include "test-succeeder.hpp"
#include "test-while.hpp"


// externs
// ------------------------------

int MockLeaf__activated = 0;
int MockLeaf__resumed   = 0;
int MockFailOnThirdCall__activated;
int MockFailOnThirdCall__resumed;


using namespace Banyan;

// Tests
// ------------------------------

int main() {
  p_header("Inverter");
  {
    reset();
    Node     Inv = TestInverter();
    Instance bt(&Inv, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 1);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Repeater");
  {
    reset();
    Node     Rep = TestRepeater();
    Instance bt(&Rep, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 6);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Selector");
  {
    reset();
    Node     Sel = TestSelector();
    Instance bt(&Sel, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 4);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Sequence");
  {
    reset();
    Node     Seq = TestSequence();
    Instance bt(&Seq, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 5);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("Succeeder");
  {
    reset();
    Node     Succ = TestSucceeder();
    Instance bt(&Succ, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 2);
    p_assert(MockLeaf__resumed == 0);
  }


  p_header("While");
  {
    reset();
    Node     While = TestWhile();
    Instance bt(&While, 7459);
    bt.begin();

    p_assert(bt.stack.size() == 0);
    p_assert(MockLeaf__activated == 2);
    p_assert(MockFailOnThirdCall__activated == 3);
  }


  return 0;
}
