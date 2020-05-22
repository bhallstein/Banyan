//
//  NodeLoaderWinCtrlr.h
//  Syncarp
//
//  Created by Ben on 27/09/2015.
//  Copyright © 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Document;

@interface NodeLoaderWinCtrlr : NSWindowController

typedef void (^FileDropCallback)(NSArray*);

-(instancetype)initWithDoc:(Document*)doc;
-(void)setCB:(FileDropCallback)cb;
-(void)disp;

@end
