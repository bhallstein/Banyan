#ifndef __Wrapper_h
#define __Wrapper_h

#include "Banyan/GenericTree/Diatom/Diatom.h"
#include <vector>

struct Wrapper {
  Diatom d;
  std::vector<int> children;
  bool destroyed;

  bool hasPosition() {
    Diatom &x = d["posX"];
    Diatom &y = d["posY"];
    return x.is_number() && y.is_number();
  }
};

template<class Functor>
void walk(std::vector<Wrapper> &vec, Wrapper &n, Functor f) {
  f(n);
  for (auto &m : n.children) walk(vec, vec[m], f);
}

template<class F1, class F2, class F3>
void walk(std::vector<Wrapper> &vec,
      Wrapper &n,
      F1 f,
      F2 fRec,
      F3 fDerec,
      Wrapper *parent = NULL,
      int childIndex = -1) {
  f(n, parent, childIndex);
  fRec();
  int c = 0;
  for (auto &m : n.children) walk(vec, vec[m], f, fRec, fDerec, &n, c++);
  fDerec();
}

#endif

