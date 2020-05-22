//
//  GraphPaperView.m
//  Syncarp
//
//  Created by Ben on 25/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "GraphPaperView.h"

#define DISP [self setNeedsDisplay:YES]

@interface GraphPaperView () {
	NSSize tileSize;
	float tileScale;
}
@property NSColor *bg_tile;
@end


@implementation GraphPaperView
static const NSSize unitSize = {1.0, 1.0};

-(void)awakeFromNib {
	NSImage *im = [NSImage imageNamed:@"bg_tile"];
	tileSize = im.size;
	tileScale = 0.1;  // 0.6
	
	self.bg_tile = [NSColor colorWithPatternImage:im];
}

-(void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	
	NSSize viewScale = [self convertSize:unitSize toView:nil];
	viewScale.width /= tileScale;
	viewScale.height /= tileScale;
	[self resetScaling];
	[self scaleUnitSquareToSize:NSMakeSize(tileScale*viewScale.width, tileScale*viewScale.height)];
	
	float nVTiles = self.frame.size.height / (tileSize.height * tileScale * viewScale.height);
	float fractionalTileLeftOver = nVTiles - (int)nVTiles;
	float correction = -(1-fractionalTileLeftOver) * tileSize.height * tileScale * viewScale.height;
//	NSLog(@"%f", viewScale.height);
	
	[[NSGraphicsContext currentContext] setPatternPhase:NSMakePoint(0, correction)];
	
	[self.bg_tile set];
	NSRectFill(self.bounds);
}



-(void)resetScaling {
	[self scaleUnitSquareToSize:[self convertSize:unitSize fromView:nil]];
}

-(void)setScale:(NSSize)newScale {
	[self resetScaling];
	[self scaleUnitSquareToSize:newScale];
	DISP;
}

@end
