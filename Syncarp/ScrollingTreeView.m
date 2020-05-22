//
//  ScrollingTreeView.m
//  Syncarp
//
//  Created by Ben on 23/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "ScrollingTreeView.h"
#import "Document.h"
#import "Wrapper.h"
#import "GraphPaperView.h"

/*
  Todo:
    - Manage an in-flight connection
    - Get part of clicked node (to perform different actions)
    - Highlight nodes with wrong number of children in red
*/


@interface ScrollingTreeView () {
	NSSize  scale;
	NSPoint scroll;
	
	bool laidOutNodes;
	
	Wrapper *selectedNode;
	Wrapper *highlightedNode;
	
	bool dragLoop;
	NSTimer *dragTimer;
	NSPoint dragInitial;
}

@property IBOutlet GraphPaperView *graphPaperView;

@end


#pragma mark Node drawing constants

const float node_aspect_ratio = 1.6;
const float node_width = 110;

const float node_circle_size = 5;
const float node_parent_circle_offset_x = 6;
const float node_parent_circle_offset_y = 9;
const float node_cnxn_circle_xoffset = 8;

const float nodeHSpacing = 70.0;
const float nodeVSpacing = 90.0;

const std::map<std::string, NSColor*> node_colours = {
	{ "Inverter",  [NSColor purpleColor] },
	{ "Repeater",  [NSColor greenColor] },
	{ "Selector",  [NSColor orangeColor] },
	{ "Sequence",  [NSColor yellowColor] },
	{ "Succeeder", [NSColor blackColor] },
	{ "While",     [NSColor lightGrayColor] },
	{ "Unknown",   [NSColor redColor] }
};

float node_height() {
	return node_width/node_aspect_ratio;
}


@implementation ScrollingTreeView
static const NSSize unitSize = {1.0, 1.0};

-(void)awakeFromNib {
	[self.window makeFirstResponder:self];
	[self registerForDraggedTypes:@[NSPasteboardTypeString]];
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	if ([pb.types containsObject:NSPasteboardTypeString])
		return NSDragOperationCopy;
	
	return NSDragOperationNone;
}
-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([pb.types containsObject:NSPasteboardTypeString]) {
		NSString *type = [pb stringForType:NSPasteboardTypeString];
		NSPoint p = [self convertedPoint:[sender draggingLocation]];
		p.x -= node_width / 2;
		p.y -= node_height() / 2;
		
		[self.doc addNodeOfType:type at:p];
		DISP;
	}
	
	return YES;
}

-(Document*)doc {
	return [[[self window] windowController] document];
}
-(std::vector<Wrapper>*)nodes {
	return (std::vector<Wrapper>*) self.doc.getNodes;
}

-(NSSize)scale {
	return [self convertSize:unitSize toView:nil];
}
-(void)setScale:(NSSize)newScale {
	[self resetScaling];
	[self scaleUnitSquareToSize:newScale];
	DISP;
}
-(void)resetScaling {
	[self scaleUnitSquareToSize:[self convertSize:unitSize fromView:nil]];
}

-(BOOL)acceptsFirstResponder {
	return YES;
}


-(Wrapper*)findNodeAtPosition:(NSPoint)p {
	std::vector<Wrapper> *nodes = self.nodes;
	if (!nodes) return NULL;
	
	Wrapper *n = NULL;
	for (auto &w : *nodes)
		if (w.hasPosition()) {
			float x = w.d["posX"].number_value();
			float y = w.d["posY"].number_value();
			if (p.x >= x && p.y >= y &&
				p.x < x + node_width &&
				p.y < y + node_height()) n = &w;
		}
	return n;
}


-(void)layOutTree {
	Wrapper *topNode = self.doc.topNode;
	if (!topNode) return;
	
	int recursionLevel = 0;
	auto fLayout =
		[&](Wrapper &n, Wrapper *parent, int childIndex) {
			if (n.hasPosition()) return;
			if (!parent) {
				n.d["posX"] = self.bounds.size.width*0.5 - node_width*0.5;
				n.d["posY"] = 20.0;
				return;
			}
			
			float parX = parent->d["posX"].number_value();
			float parY = parent->d["posY"].number_value();
			
			double posX = parX - 40 + childIndex*nodeHSpacing;
			double posY = parY + nodeVSpacing + childIndex*4;
			
			n.d["posX"] = posX;
			n.d["posY"] = posY;
		};
	
	walk(
		 *self.nodes,
		 *topNode,
		 fLayout,
		 [&]() { ++recursionLevel; },
		 [&]() { --recursionLevel; }
		 );
	
	laidOutNodes = true;
}


void drawNode(int x, int y, NSColor *base_col, bool selected, const char *str_name, bool leaf, NSPoint offset) {
	x += offset.x;
	y += offset.y;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path appendBezierPathWithRoundedRect:NSMakeRect(x, y, node_width, node_width / node_aspect_ratio)
								  xRadius:3.5
								  yRadius:3.5];
	[base_col set];
	[path fill];
	
	// White overlay gradient (reflection)
	NSGradient *grad;
	grad = [[NSGradient alloc] initWithColorsAndLocations:
			[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.0], 0.0,
			[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.3], 0.5,
			[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.0], 0.51, nil];
	[grad drawInBezierPath:path angle:90.0];
	
	// Black overlay gradient
	grad = [[NSGradient alloc] initWithColorsAndLocations:
			[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0], 0.0,
			[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.2], 1.0, nil];
	[grad drawInBezierPath:path angle:90.0];
	
	if (selected)  [[NSColor colorWithDeviceRed:0.19 green:0.97 blue:1.00 alpha:1.0] set], [path setLineWidth:3.0];
	else           [[NSColor colorWithDeviceRed:0.48 green:0.48 blue:0.48 alpha:1.0] set], [path setLineWidth:1.4];
	[path stroke];
	
	// Name
	NSString *name = [NSString stringWithFormat:@"%s", str_name];
	[name drawAtPoint:NSMakePoint(x+15, y+3)
	   withAttributes:@{
						NSFontAttributeName: [NSFont fontWithName:@"PTSans-Bold" size:13.0],
						NSForegroundColorAttributeName: [NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.9]
						}];
	
	// Attachment circle - parent
	NSBezierPath *circle_path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x+node_parent_circle_offset_x,
																				  y+node_parent_circle_offset_y,
																				node_circle_size, node_circle_size)];
	[[NSColor whiteColor] set];
	[circle_path fill];
}

void drawLineBetweenNodes(int x1, int y1, int x2, int y2, NSPoint offset, int childInd) {
	x1 += offset.x;
	x2 += offset.x;
	y1 += offset.y;
	y2 += offset.y;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	float node_height = node_width / node_aspect_ratio;
	
	float startX = x1 + node_parent_circle_offset_x + node_circle_size*0.5;
	float startY = y1 + node_parent_circle_offset_y + node_circle_size*0.5;
	
	float endX = x2 + node_parent_circle_offset_x + childInd*node_cnxn_circle_xoffset;
	float endY = y2 + node_height - 9;
	
	NSBezierPath *circle_path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(endX-node_circle_size*0.5,
																				  endY-node_circle_size*0.5,
																				  node_circle_size, node_circle_size)];
	[[NSColor whiteColor] set];
	[circle_path fill];
	
	[path moveToPoint:NSMakePoint(startX, startY)];
	
	[path curveToPoint:NSMakePoint(endX, endY)
		 controlPoint1:NSMakePoint(startX, (startY+endY)*0.5)
		 controlPoint2:NSMakePoint(endX, (startY+endY)*0.5)];
	
	[[NSColor lightGrayColor] set];
	[path setLineWidth:3.0];
	[path setLineCapStyle:NSRoundLineCapStyle];
	[path stroke];
}

-(void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	
	if (!laidOutNodes) [self layOutTree];
	
	std::vector<float> cnxns;
	
	for (auto &i : *self.nodes) {
		if (i.destroyed) continue;
		
		const std::string &type = i.d["type"].str_value();
		NSColor *col = [NSColor grayColor];
		auto it = node_colours.find(type);
		if (it != node_colours.end()) col = it->second;
		
		float posX = i.d["posX"].number_value();
		float posY = i.d["posY"].number_value();
		drawNode(posX, posY, col, &i == selectedNode, type.c_str(), false, scroll);
		int c_ind = 0;
		for (auto c : i.children) {
			auto &nc = self.nodes->at(c);
			cnxns.push_back(posX);
			cnxns.push_back(posY);
			cnxns.push_back(nc.d["posX"].number_value());
			cnxns.push_back(nc.d["posY"].number_value());
			cnxns.push_back(c_ind++);
		}
	}
	
	for (int i=0, n = (int)cnxns.size(); i < n; i += 5)
		drawLineBetweenNodes(cnxns[i+2], cnxns[i+3], cnxns[i], cnxns[i+1], scroll, cnxns[i+4]);
}

-(BOOL)isFlipped {
	return YES;
}


// Scrolly things

-(void)magnifyWithEvent:(NSEvent *)event {
	float scaleFactor = (1.0 + event.magnification);
	float prevScale = self.scale.width;
	float newScale = scaleFactor * prevScale;
	
	float w = self.bounds.size.width;
	float h = self.bounds.size.height;
	
	scroll.x -= (w - w/scaleFactor) * 0.5;
	scroll.y -= (h - h/scaleFactor) * 0.5;
	
	NSSize sc = NSMakeSize(newScale, newScale);
	[self setScale:sc];
	[self.graphPaperView setScale:sc];
}
-(void)scrollWheel:(NSEvent *)event {
	float coeff = 4.0;
	
	scroll.x += event.deltaX * coeff;
	scroll.y += event.deltaY * coeff;
	
	DISP;
}

-(NSPoint)convertedPoint:(NSPoint)p {
	p = [self convertPoint:p fromView:nil];
	p.x -= scroll.x;
	p.y -= scroll.y;
	return p;
}
-(NSPoint)convertedPointForEvent:(NSEvent*)ev {
	return [self convertedPoint:ev.locationInWindow];
}
-(NSPoint)convertCurrentMouseLocation {
	NSPoint p = [self.window mouseLocationOutsideOfEventStream];
	return [self convertedPoint:p];
}

-(void)mouseDown:(NSEvent *)ev {
	NSPoint p = [self convertedPointForEvent:ev];
	printf("mouseDown: %.1f,%.1f\n", p.x, p.y);

	Wrapper *w = [self findNodeAtPosition:p];
	if (w) {
		selectedNode = w;
		[self startMouseDragAt:p];
	}
	else {
		selectedNode = NULL;
		[self endMouseDrag];
	}
	
	DISP;
	

}
-(void)mouseUp:(NSEvent *)ev {
	if (dragLoop)
		[self endMouseDrag];
}
-(void)keyDown:(NSEvent *)ev {
	unsigned int x = [ev.characters characterAtIndex:0];
	
	// Delete
	if (x == 8 || x == 127)
		if (selectedNode)
			[self.doc destroyNode:selectedNode];
	
	DISP;
}


-(void)startMouseDragAt:(NSPoint)p {
	dragLoop = true;
	dragTimer = [NSTimer scheduledTimerWithTimeInterval:0.04 target:self selector:@selector(dragCB:) userInfo:nil repeats:YES];
	dragInitial = p;
}
-(void)endMouseDrag {
	dragLoop = false;
	[dragTimer invalidate];
}
-(void)dragCB:(NSEvent*)ev {
	if (!selectedNode) {
		[dragTimer invalidate];
		return;
	}
	
	NSPoint p = [self convertCurrentMouseLocation];
	NSPoint delta = {
		p.x - dragInitial.x,
		p.y - dragInitial.y
	};
	dragInitial = p;
	selectedNode->d["posX"] = selectedNode->d["posX"].number_value() + delta.x;
	selectedNode->d["posY"] = selectedNode->d["posY"].number_value() + delta.y;
	
	DISP;
}


@end
