#include "Banyan.hpp"
#include "mocks.hpp"

inline Node TestInverter() {
  return Inverter({MockLeaf(false)});
}
