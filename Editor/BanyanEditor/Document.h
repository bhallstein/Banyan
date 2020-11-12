#import <Cocoa/Cocoa.h>
#include <vector>
#include "Diatom.h"
#include "Helpers.h"

@interface Document : NSDocument <NSTextFieldDelegate>

@property (nonatomic) UID selectedNode;

// Tree manipulation
-(void)detach:(UID)n;
-(Diatom)mkNodeOfType:(std::string)type atPos:(NSPoint)p;
-(void)insert:(Diatom)n withParent:(UID)parent withIndex:(int)i;
-(UID)nodeAtPoint:(NSPoint)p nodeWidth:(float)w nodeHeight:(float)h;
-(std::vector<Diatom>&)getTree;
-(Diatom&)getNode:(UID)uid;
-(bool)containsUnknownNodes;

// Node definitions
-(std::vector<Diatom>)allNodeDefs;

// Zoom
-(void)zoomIn;
-(void)zoomOut;

@end

