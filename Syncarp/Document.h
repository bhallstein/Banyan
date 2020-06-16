#import <Cocoa/Cocoa.h>
#include <vector>
#include "Diatom.h"
#include "Helpers.h"

@interface Document : NSDocument <NSTextFieldDelegate>

@property (nonatomic) BOOL loaderWinOpen;
@property (nonatomic) UID selectedNode;

// Tree manipulation
-(void)detach:(UID)n;
-(Diatom)mkNodeOfType:(std::string)type atPos:(NSPoint)p;
-(void)insert:(Diatom)n withParent:(UID)parent withIndex:(int)i;
-(UID)nodeAtPoint:(NSPoint)p nodeWidth:(float)w nodeHeight:(float)h;
-(std::vector<Diatom>&)getTree;
-(Diatom&)getNode:(UID)uid;

// Node definitions
-(std::vector<Diatom>)documentNodeDefs;
-(std::vector<Diatom>)allNodeDefs;
-(void*)getDefinitionFiles;

@end

