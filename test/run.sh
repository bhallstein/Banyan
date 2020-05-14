clang++ -std=c++11                             \
   TreeDef_Serialization.cpp                   \
  _Register_Test_Nodes.cpp                     \
  ../../Diatom/Diatom.cpp                      \
  ../../Diatom/Diatom-Storage.cpp              \
  ../../Diatomize/Diatomize.cpp                \
  -I ..                                        \
  -I ../../C++\ Containers/GenericTree         \
  -I ../../Diatom                              \
  -I ../../Diatomize                           \
  -I ../../C++\ Containers/ChunkVector         \
  -I ../../C++\ Containers/StackAllocators     \
  -o ser #&&
# \
# clang++ -std=c++11                             \
#   TreeInst.cpp                                 \
#   _Register_Test_Nodes.cpp                     \
#   ../../Diatom/Diatom.cpp                      \
#   ../../Diatom/Diatom-Storage.cpp              \
#   ../../Diatomize/Diatomize.cpp                \
#   -I ..                                        \
#   -I ../../C++\ Containers/GenericTree         \
#   -I ../../GenericTree                         \
#   -I ../../Diatom                              \
#   -I ../../Diatomize                           \
#   -I ../../C++\ Containers/ChunkVector         \
#   -I ../../C++\ Containers/StackAllocators     \
#   -o inst && \
# \
# ./ser &&
# \
# ./inst

