clang++ -std=c++11     -g                        \
  register-test-nodes.cpp                        \
  ../GenericTree/Diatom/Diatomize/Diatomize.cpp  \
  test.cpp                                       \
  && ./a.out

