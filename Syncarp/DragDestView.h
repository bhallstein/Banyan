#import <Cocoa/Cocoa.h>

typedef void (^DragTest_FileDropCallback)(NSArray*);


@interface DragDestView : NSView

@property NSTextField *textField;
@property NSString *textField_origStr;

-(void)setFileDropCallback:(DragTest_FileDropCallback)cb;
  // Callback should expect an NSArray of NSStrings (file paths)

@end

