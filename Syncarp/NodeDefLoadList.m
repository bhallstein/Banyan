//
//  Document view for scrollview of built in nodes
//

#import "NodeDefLoadList.h"
#import "Document.h"
#import "AppDelegate.h"
#include "Diatom.h"
#include <vector>
#include <map>

#define COL(r, g, b) [NSColor colorWithDeviceRed:r/255. green:g/255. blue:b/255. alpha:1]

@interface NodeDefLoadList () {
    
}

@end


@implementation NodeDefLoadList

-(instancetype)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
        
	}
	return self;
}

-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }

-(BOOL)isFlipped { return YES; }

-(void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	
    [[NSColor redColor] set];
    NSRectFill(self.bounds);
    
//    Document *doc = [[NSDocumentController sharedDocumentController] currentDocument];
//	auto defs = (std::vector<Diatom>*) doc.getAllNodeDefs;
//	if (!defs) return;
	
	// ...
	
//    free(defs);
//	[self setFrameSize:NSMakeSize(w, h-1)];
}



@end
