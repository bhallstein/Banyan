#import <Cocoa/Cocoa.h>

class Diatom;

@interface AppDelegate : NSObject <NSApplicationDelegate>

-(Diatom)getNodeWithType:(const char *)type;
-(void*)builtInNodes;

@end

