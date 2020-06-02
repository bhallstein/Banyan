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
#include "Helpers.h"
#include <map>


@interface ScrollingTreeView () {
  NSSize  scale;
  NSPoint scroll;

  bool laidOutNodes;

  Wrapper *selectedNode;
  Wrapper *highlightedNode;
  Wrapper *hoveredNode;

  struct InFlightConnection {
    enum ConnectionType { None, FromChild, FromParent } type;
    Wrapper *fromNode;
    Wrapper *toNode_prev;
    NSPoint currentPosition;
    int index_of_child_in_parent_children;
    int temporary_index_of_child_in_parent_children;
  } inFlightConnection;

  bool ifc_forbidden;
  bool ifc_attached;

  NSTimer *dragTimer;
  NSPoint dragInitial;
}

@end


#pragma mark Node drawing constants

const float node_aspect_ratio = 1.6;
const float node_width = 110;

const float node_circle_size = 5;
const NSPoint node_half_circle_size = (NSPoint) { node_circle_size*0.5, node_circle_size*0.5};
const float node_parent_circle_offset_x = 6;
const float node_parent_circle_offset_y = 9;
const float node_child_circle_offset_y = 9;
const float node_cnxn_circle_xoffset = 8;

const float nodeHSpacing = 70.0;
const float nodeVSpacing = 90.0;

const std::map<std::string, NSColor*> node_colours = {
  { "Inverter",  [NSColor systemRedColor]    },
  { "Repeater",  [NSColor systemPurpleColor] },
  { "Selector",  [NSColor systemOrangeColor] },
  { "Sequence",  [NSColor systemTealColor]   },
  { "Succeeder", [NSColor systemGreenColor]  },
  { "While",     [NSColor systemBrownColor]  },
  { "Unknown",   [NSColor systemGrayColor]   },
};

float node_height() {
  return node_width/node_aspect_ratio;
}
#define NSPointAdd(p1, p2) ((NSPoint) { p1.x + p2.x, p1.y + p2.y })

@implementation ScrollingTreeView
static const NSSize unitSize = {1.0, 1.0};

-(void)awakeFromNib {
  [self.window makeFirstResponder:self];
  [self registerForDraggedTypes:@[NSPasteboardTypeString]];

  ifc_forbidden = false;

  NSTrackingAreaOptions tr_options = (
    NSTrackingActiveAlways |
    NSTrackingInVisibleRect |
    NSTrackingMouseEnteredAndExited |
    NSTrackingMouseMoved
  );
  [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:[self bounds]
                                                     options:tr_options
                                                       owner:self
                                                    userInfo:nil]];
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];
  if ([pb.types containsObject:NSPasteboardTypeString]) {
    return NSDragOperationCopy;
  }

  return NSDragOperationNone;
}
-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];

  if ([pb.types containsObject:NSPasteboardTypeString]) {
    NSString *type = [pb stringForType:NSPasteboardTypeString];
    NSPoint p = [self convertedPoint:[sender draggingLocation]];
    p.x -= node_width / 2;
    p.y -= node_height() / 2;

    hoveredNode = [DOCW addNodeOfType:type at:p];
    DISP;
  }

  return YES;
}

-(std::vector<Wrapper>*)nodes {
  return (std::vector<Wrapper>*) DOCW.getNodes;
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
  for (auto &w : *nodes) {
    if (!w.destroyed && w.hasPosition()) {
      float x = w.d["posX"].value__number;
      float y = w.d["posY"].value__number;
      bool overlaps = (
        p.x >= x &&
        p.y >= y &&
        p.x < x + node_width &&
        p.y < y + node_height()
      );
      if (overlaps) {
        n = &w;
      }
    }
  }

  return n;
}

BOOL isOverParentConnector(Wrapper *n, NSPoint p) {
  float forgivingness = 4.0;
  NSPoint coord = attachmentCoord_Parent_forNode(n);
  return (
    p.x >  coord.x - node_circle_size*0.5 - forgivingness &&
    p.x <= coord.x + node_circle_size*0.5 + forgivingness &&
    p.y >  coord.y - node_circle_size*0.5 - forgivingness &&
    p.y <= coord.y + node_circle_size*0.5 + forgivingness
  );
}

int isOverChildConnector(Wrapper *n, NSPoint p, Wrapper *hoveredNode, InFlightConnection *cnxn) {
  float v_forgivingness = 14.0;

  int n_points =
    (int) n->children.size() +
    (shouldDrawExtraChildConnector(n, hoveredNode, cnxn) ? 1 : 0);
  float nodeX = n->d["posX"].value__number;
  float nodeY = n->d["posY"].value__number;

  float box_l = nodeX + node_parent_circle_offset_x;
  float box_r = box_l + n_points*node_cnxn_circle_xoffset;
  float box_t = nodeY + node_height() - node_child_circle_offset_y - v_forgivingness;
  float box_b = box_t + node_circle_size + v_forgivingness;

  if (p.x < box_l || p.x >= box_r || p.y < box_t || p.y >= box_b) {
    return -1;
  }

  return (p.x - box_l) / (box_r - box_l) * n_points;
}


-(void)layOutTree {
  Wrapper *topNode = DOCW.topNode;
  if (!topNode) {
    return;
  }

  int recursionLevel = 0;
  auto fLayout = [&](Wrapper &n, Wrapper *parent, int childIndex) {
    if (n.hasPosition()) return;
    if (!parent) {
      n.d["posX"] = self.bounds.size.width*0.5 - node_width*0.5;
      n.d["posY"] = 20.0;
      return;
    }

    float parX = parent->d["posX"].value__number;
    float parY = parent->d["posY"].value__number;

    double posX = parX - 40 + childIndex*nodeHSpacing;
    double posY = parY + nodeVSpacing + childIndex*4;

    n.d["posX"] = posX;
    n.d["posY"] = posY;
  };

  walk(*self.nodes,
     *topNode,
     fLayout,
     [&]() { ++recursionLevel; },
     [&]() { --recursionLevel; });

  laidOutNodes = true;
}

NSPoint attachmentCoord_Parent_forNode(Wrapper *n) {
  float x = n->d["posX"].value__number;
  float y = n->d["posY"].value__number;

  return (NSPoint) {
    x + node_parent_circle_offset_x + node_circle_size*0.5,
    y + node_parent_circle_offset_y + node_circle_size*0.5
  };
}

NSPoint attachmentCoord_Child_forNode(Wrapper *n, int childIndex) {
  float x = n->d["posX"].value__number;
  float y = n->d["posY"].value__number;

  return (NSPoint) {
    x + node_parent_circle_offset_x + childIndex*node_cnxn_circle_xoffset + node_circle_size*0.5,
    y + node_height() - node_child_circle_offset_y
  };
}

bool shouldDrawExtraChildConnector(Wrapper *n, Wrapper *hoveredNode, InFlightConnection *cx) {
  Diatom &maxCh = n->d["maxChildren"];
  if (!maxCh.is_empty() && maxCh.value__number != -1 && maxCh.value__number <= n->children.size()) {
    return false;
  }

  bool just_hovering = n == hoveredNode && cx->type == InFlightConnection::None;
  bool drawing_from_child_to_this_node = n == hoveredNode && cx->type == InFlightConnection::FromChild;
  bool drawing_from_this_node_as_parent = cx->type == InFlightConnection::FromParent && n == cx->fromNode;

  if (just_hovering) {
    return true;
  }
  if (drawing_from_child_to_this_node) {
    return true;
  }
  if (drawing_from_this_node_as_parent) {
    return true;
  }
  return false;
}

void drawNode(Wrapper *n, NSPoint scroll, bool selected, bool hover, bool leaf, bool draw_extra_child_connector) {
  Diatom &d = n->d;

  float x = d["posX"].value__number + scroll.x;
  float y = d["posY"].value__number + scroll.y;

  // Make main shape
  NSBezierPath *path_main = [NSBezierPath bezierPath];
  [path_main appendBezierPathWithRoundedRect:NSMakeRect(x, y, node_width, node_width / node_aspect_ratio)
                                     xRadius:3.5
                                     yRadius:3.5];


  // Get node-specific colour
  NSColor *col__node = [NSColor blackColor];
  auto it = node_colours.find(d["type"].value__string);
  if (it != node_colours.end()) {
    col__node = it->second;
  }
  if (selected) {
    col__node = [NSColor systemBlueColor];
  }


  // Attachment circle – parent
  NSPoint pt_pcircle = attachmentCoord_Parent_forNode(n);
  pt_pcircle = NSPointAdd(pt_pcircle, scroll);
  pt_pcircle = NSPointAdd(pt_pcircle, -node_half_circle_size);
  NSBezierPath *path_ac_parent = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(pt_pcircle.x, pt_pcircle.y,
                                                                                   node_circle_size, node_circle_size)];


  // Name
  NSString *name = [NSString stringWithFormat:@"%s", d["type"].value__string.c_str()];
  NSShadow *shadow = [[NSShadow alloc] init];
  [shadow setShadowBlurRadius:1.0f];
  [shadow setShadowColor:[NSColor darkGrayColor]];
  [shadow setShadowOffset:CGSizeMake(0, -1.0f)];


  // Draw
  [[NSColor whiteColor] set];
  [path_main fill];

  [col__node set];
  [path_main setLineWidth:(selected ? 2.5 : 1.5)];
  [path_main stroke];

  [name drawAtPoint:NSMakePoint(x+15, y+3)
     withAttributes:@{
       NSFontAttributeName: [NSFont systemFontOfSize:12. weight:NSFontWeightBold],
       NSForegroundColorAttributeName: [NSColor blackColor],
       NSStrokeWidthAttributeName: @-1.0,
     }];

  [[NSColor blackColor] set];
  [path_ac_parent fill];

  int n_children_to_draw = (int)n->children.size();
  if (draw_extra_child_connector) n_children_to_draw += 1;

  for (int i=0; i < n_children_to_draw; ++i) {
    NSPoint p = attachmentCoord_Child_forNode(n, i);
    p = NSPointAdd(p, scroll);
    p = NSPointAdd(p, -node_half_circle_size);
    path_ac_parent = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x, p.y, node_circle_size, node_circle_size)];
    [path_ac_parent fill];
  }
}

void drawConnection(NSPoint child_cnxn_pos, NSPoint parent_cnxn_pos, NSPoint scroll, bool inFlight, bool forbidden = false, bool attached = false) {
  NSBezierPath *path = [NSBezierPath bezierPath];

  child_cnxn_pos  = NSPointAdd(child_cnxn_pos, scroll);
  parent_cnxn_pos = NSPointAdd(parent_cnxn_pos, scroll);

  [path moveToPoint:child_cnxn_pos];
  [path curveToPoint:parent_cnxn_pos
       controlPoint1:NSMakePoint(child_cnxn_pos.x, (child_cnxn_pos.y + parent_cnxn_pos.y)*0.5)
       controlPoint2:NSMakePoint(parent_cnxn_pos.x, (child_cnxn_pos.y + parent_cnxn_pos.y)*0.5)];

  if (forbidden)     { [[NSColor redColor] set]; }
  else if (attached) { [[NSColor blueColor] set]; }
  else               { [[NSColor lightGrayColor] set]; }

  [path setLineWidth:3.0];
  [path setLineCapStyle:NSRoundLineCapStyle];
  if (inFlight) {
    CGFloat pattern[] = { 8.0, 8.0 };
    [path setLineDash:pattern count:2 phase:0];
  }
  [path stroke];
}

int indexInChildren(Wrapper *p, Wrapper *n, std::vector<Wrapper> &nodes) {
  int n_index = index_in_vec(nodes, n);
  for (int i=0; i < p->children.size(); ++i) {
    if (p->children[i] == n_index) {
      return i;
    }
  }
  return -1;
}

-(void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  if (!laidOutNodes) {
    [self layOutTree];
  }

  std::vector<NSPoint> cnxns;
  for (auto &i : *self.nodes) {
    if (i.destroyed) {
      continue;
    }

    bool draw_extra_cnxn = shouldDrawExtraChildConnector(&i, hoveredNode, &inFlightConnection);
    drawNode(&i, scroll, &i == selectedNode, &i == hoveredNode, false, draw_extra_cnxn);

    // Also save node’s child connections
    int c_ind = 0;
    for (auto c : i.children) {
      auto &nc = self.nodes->at(c);
      if ((inFlightConnection.type == InFlightConnection::FromParent &&
        inFlightConnection.fromNode == &i &&
        inFlightConnection.toNode_prev == &nc) ||
        (inFlightConnection.type == InFlightConnection::FromChild &&
         inFlightConnection.fromNode == &nc &&
         inFlightConnection.toNode_prev == &i)) {
        c_ind++;
        continue;
      }
      int ind = c_ind;
      // For FromChild connections, shuffle existing connector indices
      if (inFlightConnection.type == InFlightConnection::FromChild && hoveredNode == &i) {
        int orig_cnxn_ind = inFlightConnection.index_of_child_in_parent_children;
        int temp_cnxn_ind = inFlightConnection.temporary_index_of_child_in_parent_children;

        if (temp_cnxn_ind != -1) {
          if (inFlightConnection.toNode_prev == &i) {
            if (orig_cnxn_ind < c_ind && temp_cnxn_ind >= c_ind) {
              --ind;
            }
            if (orig_cnxn_ind > c_ind && temp_cnxn_ind <= c_ind) {
              ++ind;
            }
          }
          else if (c_ind >= temp_cnxn_ind) {
            ++ind;
          }
        }
      }
      cnxns.push_back(attachmentCoord_Parent_forNode(&nc));
      cnxns.push_back(attachmentCoord_Child_forNode(&i, ind));
      ++c_ind;
    }
  }

  for (int i=0, n = (int)cnxns.size(); i < n; i += 2) {
    drawConnection(cnxns[i], cnxns[i+1], scroll, false);
  }

  // Also draw in-flight connection, if present
  if (inFlightConnection.type == InFlightConnection::FromChild) {
    drawConnection(
      attachmentCoord_Parent_forNode(inFlightConnection.fromNode),
      inFlightConnection.currentPosition,
      scroll,
      true,
      ifc_forbidden,
      ifc_attached
    );
  }
  if (inFlightConnection.type == InFlightConnection::FromParent) {
    drawConnection(
      attachmentCoord_Child_forNode(inFlightConnection.fromNode, inFlightConnection.index_of_child_in_parent_children),
      inFlightConnection.currentPosition,
      scroll,
      true,
      ifc_forbidden,
      ifc_attached
    );
  }
}

-(BOOL)isFlipped {
  return YES;
}


// Scroll
// ---------------------------

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
  Wrapper *w = [self findNodeAtPosition:p];
  int child_ind;

  if (w) {
    if (selectedNode != w) {
      selectedNode = w;
      [DOCW setSelectedNode:w];
    }

    if (isOverParentConnector(w, p)) {

      // If an orphan, create a new connection from the selected node
      if ([DOCW nodeIsOrphan:selectedNode]) {
        inFlightConnection = {
          InFlightConnection::FromChild,
          selectedNode,
          NULL,
          p,
          0
        };
        [self startMouseDragAt:p];
      }

      // If not an orphan, set connection from parent node
      else {
        Wrapper *parent = [DOCW parentOfNode:selectedNode];
        if (!parent)
          NSLog(@"Oh dear - expected to find a parent node!");
        inFlightConnection = {
          InFlightConnection::FromParent,
          parent,
          selectedNode,
          p,
          indexInChildren(parent, selectedNode, *self.nodes)
        };
        [self startMouseDragAt:p];
      }
    }

    else if ((child_ind = isOverChildConnector(w, p, hoveredNode, &inFlightConnection)) != -1) {

      // If this is a *new* child connection...
      if (child_ind >= w->children.size()) {
        inFlightConnection = {
          InFlightConnection::FromParent,
          w,
          NULL,
          p,
          child_ind,
          -1
        };
        [self startMouseDragAt:p];
      }

      // If not...
      else {
        Wrapper *child = &self.nodes->at(w->children[child_ind]);
        inFlightConnection = {
          InFlightConnection::FromChild,
          child,
          w,
          p,
          child_ind,
          -1
        };
        [self startMouseDragAt:p];
      }

    }

    else {
      [self startMouseDragAt:p];
    }
  }
  else {
    selectedNode = NULL;
    [DOCW setSelectedNode:NULL];
    [self endMouseDrag];
  }

  DISP;
}
-(void)mouseUp:(NSEvent *)ev {
  if (inFlightConnection.type == InFlightConnection::FromChild)
    [self endDrag_ConnectionFromChild:ev];
  else if (inFlightConnection.type == InFlightConnection::FromParent)
    [self endDrag_ConnectionFromParent:ev];

  [self endMouseDrag];
}
-(void)mouseMoved:(NSEvent*)ev {
  hoveredNode = [self findNodeAtPosition:[self convertedPointForEvent:ev]];

  DISP;
}
-(void)keyDown:(NSEvent *)ev {
  unsigned int c = [ev.characters characterAtIndex:0];

  if (selectedNode && (c == 8 || c == 127)) {
    [DOCW destroyNode:selectedNode];
  }

  DISP;
}

-(void)startMouseDragAt:(NSPoint)p {
  SEL sel;

  if (inFlightConnection.type == InFlightConnection::FromChild) sel = @selector(dragCB_ConnectionFromChild:);
  else if (inFlightConnection.type == InFlightConnection::FromParent) sel = @selector(dragCB_ConnectionFromParent:);
  else sel = @selector(dragCB_MoveNode:);

  dragTimer = [NSTimer scheduledTimerWithTimeInterval:0.04 target:self selector:sel userInfo:nil repeats:YES];
  dragInitial = p;
}
-(void)endMouseDrag {
  [dragTimer invalidate];
  inFlightConnection.type = InFlightConnection::None;
  DISP;
}


-(void)dragCB_MoveNode:(NSEvent*)ev {
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
  selectedNode->d["posX"] = selectedNode->d["posX"].value__number + delta.x;
  selectedNode->d["posY"] = selectedNode->d["posY"].value__number + delta.y;

  DISP;
}
-(void)dragCB_ConnectionFromChild:(NSEvent*)ev {
  NSPoint p = [self convertCurrentMouseLocation];
  inFlightConnection.currentPosition = p;

  ifc_attached = false;
  ifc_forbidden = false;
  inFlightConnection.temporary_index_of_child_in_parent_children = -1;

  hoveredNode = [self findNodeAtPosition:p];
  Wrapper *parent_of_from = [DOC parentOfNode:inFlightConnection.fromNode];
  if (hoveredNode && hoveredNode != inFlightConnection.fromNode) {
    int hovered_child_ind = isOverChildConnector(hoveredNode, p, hoveredNode, &inFlightConnection);
    if (hovered_child_ind > -1) {
      inFlightConnection.currentPosition = attachmentCoord_Child_forNode(hoveredNode, hovered_child_ind);

      // Forbidden if:
      int hov_max_children = hoveredNode->d["maxChildren"].value__number;
      if (parent_of_from != hoveredNode &&                                      // the hovered not isn't the existing parent, and
        ([DOC node:inFlightConnection.fromNode isAncestorOf:hoveredNode] ||     // (from node is ancestor of hovered node, or
        hov_max_children == hoveredNode->children.size())) {                    //  hovered node at capacity)
        ifc_forbidden = true;
      }
      else {
        ifc_attached = true;
        inFlightConnection.temporary_index_of_child_in_parent_children = hovered_child_ind;
      }
    }
  }

  DISP;
}
-(void)dragCB_ConnectionFromParent:(NSEvent*)ev {
  NSPoint p = [self convertCurrentMouseLocation];
  inFlightConnection.currentPosition = p;

  ifc_forbidden = false;
  ifc_attached = false;

  hoveredNode = [self findNodeAtPosition:p];
  if (hoveredNode && hoveredNode != inFlightConnection.fromNode && isOverParentConnector(hoveredNode, p)) {
    inFlightConnection.currentPosition = attachmentCoord_Parent_forNode(hoveredNode);
    ifc_attached = true;

    Wrapper *hov_parent = [DOC parentOfNode:hoveredNode];
    if (hov_parent && hoveredNode != inFlightConnection.toNode_prev) {
      ifc_forbidden = true;
    }

    else if ([DOC node:hoveredNode isAncestorOf:inFlightConnection.fromNode]) {
      ifc_forbidden = true;
    }
  }

  DISP;
}


-(void)endDrag_ConnectionFromChild:(NSEvent*)ev {
  NSPoint p = [self convertedPointForEvent:ev];
  hoveredNode = [self findNodeAtPosition:p];
  Wrapper *hov     = hoveredNode;
  Wrapper *from    = inFlightConnection.fromNode;
  Wrapper *to_prev = inFlightConnection.toNode_prev;
  int orig_ind = inFlightConnection.index_of_child_in_parent_children;

  // If not over a node, and a previous parent exists, detach
  if (!hov) {
    if (to_prev) [DOC detachNodeFromTree:from];
    return;
  }

  int over_cnctr = isOverChildConnector(hov, p, hov, &inFlightConnection);
  int hov_max_ch = hov->d["maxChildren"].value__number;

  // Do nothing if:
  if (over_cnctr == -1                           ||   // over a node, but not a connector
    (hov == to_prev && over_cnctr == orig_ind) ||   // over the same node and connector as before
    [DOC node:from isAncestorOf:hov]           ||   // over a target, but we are an ancestor of that target
    hov->children.size() == hov_max_ch) {           // target node is at capacity
    return;
  }

  // Detach the node
  [DOC detachNodeFromTree:from];

  // Re-add it
  [DOC makeNode:from childOf:hov atIndex:over_cnctr];
}

-(void)endDrag_ConnectionFromParent:(NSEvent*)ev {
  NSPoint p = [self convertedPointForEvent:ev];
  hoveredNode = [self findNodeAtPosition:p];
  Wrapper *hov     = hoveredNode;
  Wrapper *from    = inFlightConnection.fromNode;
  Wrapper *to_prev = inFlightConnection.toNode_prev;

  // If not over a node, and a previously connected child exists,
  // detach it
  if (!hov) {
    if (to_prev) [DOC detachNodeFromTree:to_prev];
    return;
  }

  // Do nothing if:
  if (!isOverParentConnector(hov, p)       ||     // over a node, but not a connector
    hov == to_prev                       ||     // over the same node as was connected previously
    [DOC parentOfNode:hov] != NULL  ||     // over a target, but the target already has a parent node
    [DOC node:hov isAncestorOf:from]) {      // over a target, but the target is an ancestor of the current node
    return;
  }

  // Over a valid node -- make the connection
  [DOC makeNode:hov
        childOf:from
        atIndex:inFlightConnection.index_of_child_in_parent_children];

  // If there was a previous connection, unmake it
  if (to_prev) {
    [DOC detachNodeFromTree:to_prev];
  }
}


@end