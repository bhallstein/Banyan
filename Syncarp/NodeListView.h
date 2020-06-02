#import <Cocoa/Cocoa.h>

@interface NodeListView : NSView <NSDraggingSource, NSPasteboardItemDataProvider>

@end

extern void *node_descriptions;

