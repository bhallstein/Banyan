//
//  NodeLoaderWinCtrlr.h
//  Syncarp
//
//  Created by Ben on 27/09/2015.
//  Copyright © 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NodeLoaderWinCtrlr : NSWindowController

typedef void (^FileDropCallback)(NSArray*);

-(void)setCB:(FileDropCallback)cb;

@end
