//
//  DragDestView.h
//  Syncarp
//
//  Created by Ben on 26/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^DragTest_FileDropCallback)(NSArray*);

@interface DragDestView : NSView

-(void)setFileDropCallback:(DragTest_FileDropCallback)cb;
	// Callback should expect an NSArray of NSStrings (file paths)

@end

