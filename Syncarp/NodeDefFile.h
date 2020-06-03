#ifndef NodeDefFile_h
#define NodeDefFile_h

#include <string>

struct NodeDefFile {
  bool succeeded;
  std::string path;
  std::string error_string;
};

#endif
