//
//  NodeListView.h
//  Syncarp
//
//  Created by Ben on 25/05/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NodeListView : NSView <NSDraggingSource, NSPasteboardItemDataProvider>

@end

extern void *node_descriptions;
