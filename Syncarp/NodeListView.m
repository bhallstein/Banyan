#import "NodeListView.h"
#import "Document.h"
#import "AppDelegate.h"
#include "Banyan/GenericTree/Diatom/Diatom.h"
#include "Helpers.h"
#include <vector>
#include <map>

#define DISP [self setNeedsDisplay:YES]
#define COL(r, g, b) [NSColor colorWithDeviceRed:r/255. green:g/255. blue:b/255. alpha:1]


float start_offset = 38;
float h_node = 54.;


@interface NodeListView () {
  int indexOfSelectedNode;
}

@property NSData *dragData;
@property NSImage *dragImage;
@property NSDraggingSession *dragSession;

@end


@implementation NodeListView

-(instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    indexOfSelectedNode = -1;
  }
  return self;
}

-(AppDelegate*)appDelegate {
    return (AppDelegate*)[NSApplication sharedApplication].delegate;
}

-(BOOL)isFlipped { return YES; }

-(void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  auto defs = DOCW.allNodeDefs;

  float y = start_offset;
  float w = self.frame.size.width;
  float h_total = h_node * defs.size() + start_offset;

  [@"AVAILABLE NODES:" drawAtPoint:NSMakePoint(10, 18)
                    withAttributes:@{
                      NSFontAttributeName: [NSFont systemFontOfSize:11. weight:NSFontWeightBold],
                      NSForegroundColorAttributeName: [NSColor systemGrayColor],
                    }];

  int i = 0;
  for (auto &nd : defs) {
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
    NSString *name = [NSString stringWithFormat:@"%s", nd["type"].value__string.c_str()];
    [name drawAtPoint:NSMakePoint(10.5, y + h_node/2 - 12.)
       withAttributes:@{
         NSFontAttributeName: [NSFont systemFontOfSize:13. weight:NSFontWeightBold],
         NSForegroundColorAttributeName: (sel ? [NSColor whiteColor] : [NSColor blackColor])
       }];

    // draw horizontal line
    if (&nd != &defs.back()) {
      NSRect lineRect = NSMakeRect(0, y + h_node - 1, w, 1);
      [[NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1] set];
      NSRectFill(lineRect);
    }

    y += 54;
  }

  [self setFrameSize:NSMakeSize(w, h_total-1)];
}

-(void)mouseDown:(NSEvent*)ev {
  NSPoint p = [self convertPoint:ev.locationInWindow fromView:nil];
  int ind = (p.y - start_offset) / h_node;
  indexOfSelectedNode = ind;

  DISP;
}
-(void)mouseDragged:(NSEvent*)ev {
  // Get image
  NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
  [self cacheDisplayInRect:self.bounds toBitmapImageRep:rep];

  NSRect r = NSMakeRect(0, start_offset + indexOfSelectedNode*h_node, self.bounds.size.width, h_node - 1);
  CGImageRef cgImg = CGImageCreateWithImageInRect(rep.CGImage, NSRectToCGRect(r));
  NSBitmapImageRep *rep2 = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
  CGImageRelease(cgImg);

  self.dragImage = [[NSImage alloc] initWithSize:rep2.size];
  [self.dragImage addRepresentation:rep2];

  // Get string data
  auto nodeDefs = DOCW.allNodeDefs;
  NSString *str = [NSString stringWithFormat:@"%s", nodeDefs[indexOfSelectedNode]["type"].value__string.c_str()];
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
  if ([type isEqualToString:NSPasteboardTypeString]) {
    [pb setData:self.dragData forType:type];
  }
}


-(NSDragOperation)draggingSession:(NSDraggingSession*)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
  if (context == NSDraggingContextOutsideApplication) {
    return NSDragOperationNone;
  }

  return NSDragOperationEvery;
}

-(void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
  indexOfSelectedNode = -1;
  DISP;
}

@end

