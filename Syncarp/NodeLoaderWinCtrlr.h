#import <Cocoa/Cocoa.h>

@class Document;

@interface NodeLoaderWinCtrlr : NSWindowController

typedef void (^FileDropCallback)(NSArray*);

-(instancetype)initWithDoc:(Document*)doc;
-(void)setCB:(FileDropCallback)cb;
-(void)disp;

@end

