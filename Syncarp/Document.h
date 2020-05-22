//
//  Document.h
//  Thingumy
//
//  Created by Ben on 19/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define DISP [self setNeedsDisplay:YES]

class Wrapper;

@interface Document : NSDocument

-(void*)getNodes;
-(Wrapper*)topNode;

-(void)detachNodeFromTree:(Wrapper*)n;
-(void)destroyNode:(Wrapper*)n;

-(void)addNodeOfType:(NSString*)t at:(NSPoint)p;
-(void)makeNode:(Wrapper*)A childOf:(Wrapper*)B;

@end

