#import <Cocoa/Cocoa.h>

typedef void (^FileDropCallback)(NSArray*);

@interface NodeListView : NSView <NSDraggingSource, NSPasteboardItemDataProvider>

@property (nonatomic) FileDropCallback definitionDropCallback;

@end

