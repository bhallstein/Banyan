//
//  NodeDefFile.h
//  Syncarp
//
//  Created by Ben on 04/10/2015.
//  Copyright © 2015 Ben. All rights reserved.
//

#ifndef NodeDefFile_h
#define NodeDefFile_h

#include <string>

struct NodeDefFile {
	std::string path;
	bool succeeded;
	std::string error_string;
};

#endif
