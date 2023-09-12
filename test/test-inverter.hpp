#include "Banyan.hpp"
#include "mocks.hpp"

inline Node TestInverter() {
  return Banyan::Inverter({MockLeaf(false)});
}
