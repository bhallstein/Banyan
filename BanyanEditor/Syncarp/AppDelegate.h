#import <Cocoa/Cocoa.h>
#include <string>
#include <vector>
#include <map>

class Diatom;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic) std::vector<Diatom> nodeDefs;
-(std::map<std::string, std::string>&)descriptions;

@end

