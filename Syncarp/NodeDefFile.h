#ifndef NodeDefFile_h
#define NodeDefFile_h

#include <string>

struct NodeDefFile {
  std::string path;
  bool succeeded;
  std::string error_string;
};

#endif
