#import <Cocoa/Cocoa.h>
#include <string>
#include <vector>
#include <map>

class Diatom;

@interface AppDelegate : NSObject <NSApplicationDelegate>

-(std::vector<Diatom>)builtinNodeDefs;
-(std::map<std::string, std::string>&)descriptions;

@end

