#import <Cocoa/Cocoa.h>

@interface BanyanView : NSView

-(void)zoomIn;
-(void)zoomOut;
-(void)adjustScrollX:(float)x Y:(float)y;

@end

