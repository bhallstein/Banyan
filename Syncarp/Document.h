//
//  Document.h
//  Thingumy
//
//  Created by Ben on 19/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define DISP [self setNeedsDisplay:YES]
#define index_in_vec(vec, n) int(n - &vec[0])

class Wrapper;

@interface Document : NSDocument <NSTextFieldDelegate>

-(void*)getNodes;
-(Wrapper*)topNode;

-(void)detachNodeFromTree:(Wrapper*)n;
-(void)destroyNode:(Wrapper*)n;

-(Wrapper*)addNodeOfType:(NSString*)t at:(NSPoint)p;
-(void)makeNode:(Wrapper*)A childOf:(Wrapper*)B atIndex:(int)i;

-(BOOL)nodeIsOrphan:(Wrapper*)n;
-(BOOL)node:(Wrapper*)A isAncestorOf:(Wrapper*)B;
-(Wrapper*)parentOfNode:(Wrapper*)n;

-(void)setSelectedNode:(Wrapper*)n;

@end

