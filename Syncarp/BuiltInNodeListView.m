//
//  Document view for scrollview of built in nodes
//

#import "BuiltInNodeListView.h"
#import "Document.h"
#import "AppDelegate.h"
#include "Diatom.h"
#include <vector>
#include <map>

#define COL(r, g, b) [NSColor colorWithDeviceRed:r/255. green:g/255. blue:b/255. alpha:1]

@interface BuiltInNodeListView () {
	int indexOfSelectedNode;
}

@property NSData *dragData;
@property NSImage *dragImage;
@property NSDraggingSession *dragSession;

@end


@implementation BuiltInNodeListView

-(instancetype)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		indexOfSelectedNode = -1;
	}
	return self;
}

-(AppDelegate*)appDelegate { return (AppDelegate*)[NSApplication sharedApplication].delegate; }

const std::map<std::string, std::string> descriptions = {
	{ "Inverter",  "Inverts its descendant's status" },
	{ "Repeater",  "Calls its descendant N times" },
	{ "Succeeder", "Always returns success" },
	{ "Sequence",  "Calls its descendants in order" },
	{ "Selector",  "Calls descendants until one succeeds" },
	{ "While",     "Calls a node while another succeeds" }
};

void *node_descriptions = (void*) &descriptions;

-(BOOL)isFlipped { return YES; }

-(void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
	
	auto nodes = (std::vector<Diatom>*) self.appDelegate.builtInNodes;
	if (!nodes) return;
	
	float y = 0;
	float w = self.frame.size.width;
	float h = 54.0 * nodes->size();
	
	int i = 0;
	for (auto &nd : *nodes) {
		// If selected, draw blue gradienty background
		bool sel = false;
		if (indexOfSelectedNode == i++) {
			sel = true;
			NSGradient *grad;
			grad = [[NSGradient alloc] initWithColorsAndLocations:
					COL(10, 76, 131),   0.0,
					COL(35, 132, 215), 1.0, nil];
			[grad drawInRect:NSMakeRect(0, y, w, 53) angle:-90];
		}
		
		// draw name
		NSString *name = [NSString stringWithFormat:@"%s", nd["type"].str_value().c_str()];
		[name drawAtPoint:NSMakePoint(10.5, y+7)
		   withAttributes:@{
							NSFontAttributeName: [NSFont fontWithName:@"PTSans-Bold" size:14.0],
							NSForegroundColorAttributeName: (sel ? [NSColor whiteColor] : [NSColor blackColor])
							}];
		
		// draw description
		std::string desc = "NO DESCRIPTION FOUND";
		auto it = descriptions.find(nd["type"].str_value());
		if (it != descriptions.end()) desc = it->second;
		NSString *desc_s = [NSString stringWithFormat:@"%s", desc.c_str()];
		[desc_s drawAtPoint:NSMakePoint(10, y+26)
			 withAttributes:@{
							  NSFontAttributeName: [NSFont fontWithName:@"PTSans-Regular" size:13.0],
							  NSForegroundColorAttributeName: (sel ? [NSColor whiteColor] : [NSColor blackColor])
							  }];
		
		// draw horizontal line
		if (&nd != &nodes->back()) {
			NSRect lineRect = NSMakeRect(0, y + 53, w, 1);
			[[NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1] set];
			NSRectFill(lineRect);
		}
		
		y += 54;
	}
	
	[self setFrameSize:NSMakeSize(w, h-1)];
}

-(void)mouseDown:(NSEvent*)ev {
	NSPoint p = [self convertPoint:ev.locationInWindow fromView:nil];
	int ind = p.y / 54;
	indexOfSelectedNode = ind;
	DISP;
}
-(void)mouseDragged:(NSEvent*)ev {
	// Get image
	float h = self.bounds.size.height;
	NSRect r = NSMakeRect(0, h-53-indexOfSelectedNode*54., self.bounds.size.width, 53.);
	NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect:r];
	[self cacheDisplayInRect:r toBitmapImageRep:rep];
	self.dragImage = [[NSImage alloc] initWithSize:rep.size];
	[self.dragImage addRepresentation:rep];
	
	// Get string data
	auto nodes = (std::vector<Diatom>*) self.appDelegate.builtInNodes;
	NSString *str = [NSString stringWithFormat:@"%s", (*nodes)[indexOfSelectedNode]["type"].str_value().c_str()];
	self.dragData = [str dataUsingEncoding:NSUTF8StringEncoding];
	
	// Create pasteboard item
	NSPasteboardItem *pbitem = [NSPasteboardItem new];
	[pbitem setDataProvider:self forTypes:@[NSPasteboardTypeString]];
	
	// Create dragging session
	NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbitem];
	NSPoint dragPosition = [self convertPoint:[ev locationInWindow] fromView:nil];
	float imW = self.dragImage.size.width;
	float imH = self.dragImage.size.height;
	dragPosition.x -= imW * 0.5;
	dragPosition.y -= imH * 0.5;
	NSRect draggingRect = NSMakeRect(dragPosition.x, dragPosition.y, imW, imH);
	[dragItem setDraggingFrame:draggingRect contents:self.dragImage];
	
	self.dragSession = [self beginDraggingSessionWithItems:@[dragItem] event:ev source:self];
	
}
-(void)mouseUp:(NSEvent*)ev {
	indexOfSelectedNode = -1;
	DISP;
}

-(void)pasteboard:(NSPasteboard*)pb item:(NSPasteboardItem*)item provideDataForType:(NSString*)type {
	if ([type isEqualToString:NSPasteboardTypeString])
		[pb setData:self.dragData forType:type];
}


-(NSDragOperation)draggingSession:(NSDraggingSession*)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
	if (context == NSDraggingContextOutsideApplication)
		return NSDragOperationNone;
	
	return NSDragOperationEvery;
}

-(void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	indexOfSelectedNode = -1;
	DISP;
}




@end
