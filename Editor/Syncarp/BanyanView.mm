#import "BanyanView.h"
#import "Document.h"
#include "Helpers.h"
#include "Diatom.h"
#include <map>
#include <string>


@interface BanyanView () {
  NSSize  scale;
  NSPoint scroll;

  bool laidOut;
  UID  hoveredNode;

  struct InFlightConnection {
    enum ConnectionType { None, FromChild, FromParent } type;
    UID fromNode;
    UID toNode_prev;
    NSPoint currentPosition;
    int i__child;
    int i__temporary;
  };
  InFlightConnection ifc;

  bool ifc_forbidden;
  bool ifc_attached;

  NSTimer *dragTimer;
  NSPoint dragInitial;
}

@end


// Drawing constants
// -----------------------------------

float node_aspect_ratio = 1.6;
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

NSPoint add_points(NSPoint p1, NSPoint p2) {
  return NSPoint{ p1.x + p2.x, p1.y + p2.y };
}

@implementation BanyanView
static const NSSize unitSize = {1.0, 1.0};

-(instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    [self.window makeFirstResponder:self];
    [self registerForDraggedTypes:@[NSPasteboardTypeString]];
    self.wantsLayer = YES;

    hoveredNode = NotFound;
    ifc_forbidden = false;
    ifc_attached = false;

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
  
  return self;
}

-(BOOL)acceptsFirstResponder {
  return YES;
}

-(BOOL)isFlipped {
  return YES;
}


// Scale
// ------------------------------------

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


// Draw helpers
// ------------------------------------

NSPoint attachmentCoord_Parent_forNode(Diatom *n) {
  float x = (*n)["posX"].number_value;
  float y = (*n)["posY"].number_value;

  return (NSPoint) {
    x + node_parent_circle_offset_x + node_circle_size*0.5,
    y + node_parent_circle_offset_y + node_circle_size*0.5
  };
}

NSPoint attachmentCoord_Child_forNode(Diatom *n, int childIndex) {
  float x = (*n)["posX"].number_value;
  float y = (*n)["posY"].number_value;

  return NSPoint{
    x + node_parent_circle_offset_x + childIndex*node_cnxn_circle_xoffset + node_circle_size*0.5,
    y + node_height() - node_child_circle_offset_y
  };
}

BOOL isOverParentConnector(Diatom *n, NSPoint p) {
  float forgivingness = 4.0;
  NSPoint coord = attachmentCoord_Parent_forNode(n);
  return (
    p.x >  coord.x - node_circle_size*0.5 - forgivingness &&
    p.x <= coord.x + node_circle_size*0.5 + forgivingness &&
    p.y >  coord.y - node_circle_size*0.5 - forgivingness &&
    p.y <= coord.y + node_circle_size*0.5 + forgivingness
  );
}

bool shouldDrawExtraChildConnector(Diatom *n, UID uid__hovered_node, InFlightConnection ifc) {
  Diatom max_children = (*n)["maxChildren"];
  bool capacity_full = (
    max_children.is_number() &&
    max_children.number_value != -1 &&
    n_children(n) >= max_children.number_value
  );
  if (capacity_full) {
    return false;
  }

  UID uid = (*n)["uid"].number_value;

  bool is_hovered                       = uid == uid__hovered_node;
  bool just_hovering                    = is_hovered && ifc.type == InFlightConnection::None;
  bool drawing_from_child_to_this_node  = is_hovered && ifc.type == InFlightConnection::FromChild && ifc.toNode_prev != uid;
  bool drawing_from_this_node_as_parent = ifc.type == InFlightConnection::FromParent && ifc.fromNode == uid;

  if (just_hovering)                    { return true; }
  if (drawing_from_child_to_this_node)  { return true; }
  if (drawing_from_this_node_as_parent) { return true; }
  return false;
}

int childConnector(Diatom *n, NSPoint p, UID uid__hovered_node, InFlightConnection cnxn) {
  float v_forgivingness = 14.0;

  int n_points =
    n_children(n) +
    (shouldDrawExtraChildConnector(n, uid__hovered_node, cnxn) ? 1 : 0);

  float nodeX = (*n)["posX"].number_value;
  float nodeY = (*n)["posY"].number_value;

  float box_l = nodeX + node_parent_circle_offset_x;
  float box_r = box_l + n_points*node_cnxn_circle_xoffset;
  float box_t = nodeY + node_height() - node_child_circle_offset_y - v_forgivingness;
  float box_b = box_t + node_circle_size + v_forgivingness;

  if (p.x < box_l || p.x >= box_r || p.y < box_t || p.y >= box_b) {
    return -1;
  }

  return (p.x - box_l) / (box_r - box_l) * n_points;
}


// Calculate layout when not set
// ------------------------------------

-(void)layOutTree {
  auto &tree = [DOCW getTree];

  for (int i=0; i < tree.size(); ++i) {
    Diatom &t = tree[i];

    t.recurse([&](std::string name, Diatom &n) {
      if (!is_node_diatom(&n)) {
        return;
      }
      if (node_has_position(&n)) {
        return;
      }

      UID uid = n["uid"].number_value;
      UIDParentSearchResult uid__parent = find_node_parent(t, uid);

      if (uid__parent.uid == NotFound) {
        n["posX"] = self.bounds.size.width*0.5 - node_width*0.5 + i * 200.;
        n["posY"] = 20.;
      }

      else {
        Diatom parent = get_node(t, uid__parent.uid);
        int i__child = (int) (parent.index_of(name) - parent.table_entries.begin());

        float x__parent = parent["posX"].number_value;
        float y__parent = parent["posY"].number_value;

        double x = x__parent - 40 + i__child * nodeHSpacing;
        double y = y__parent + nodeVSpacing + i__child * 4;

        n["posX"] = x;
        n["posY"] = y;
      }
    });
  }

  laidOut = true;
}


// Drawing
// ---------------------------

void drawNode(Diatom d, NSPoint scroll, bool selected, bool hover, bool leaf, bool extra_child_connector) {
  float x = d["posX"].number_value + scroll.x;
  float y = d["posY"].number_value + scroll.y;

  // Make main shape
  NSBezierPath *path_main = [NSBezierPath bezierPath];
  [path_main appendBezierPathWithRoundedRect:NSMakeRect(x, y, node_width, node_width / node_aspect_ratio)
                                     xRadius:3.5
                                     yRadius:3.5];

  // Get node-specific colour
  NSColor *node_color = [NSColor blackColor];
  auto it = node_colours.find(d["type"].string_value);
  if (it != node_colours.end()) {
    node_color = it->second;
  }
  if (selected) {
    node_color = [NSColor systemBlueColor];
  }

  // Parent connector
  NSPoint p__parent_circle = attachmentCoord_Parent_forNode(&d);
  p__parent_circle = add_points(p__parent_circle, scroll);
  p__parent_circle = add_points(p__parent_circle, NSPoint{-node_half_circle_size.x, -node_half_circle_size.y});
  NSBezierPath *path_ac_parent = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p__parent_circle.x, p__parent_circle.y,
                                                                                   node_circle_size, node_circle_size)];

  // Name
  NSString *name = [NSString stringWithFormat:@"%s", d["type"].string_value.c_str()];
  NSShadow *shadow = [[NSShadow alloc] init];
  [shadow setShadowBlurRadius:1.0f];
  [shadow setShadowColor:[NSColor darkGrayColor]];
  [shadow setShadowOffset:CGSizeMake(0, -1.0f)];

  // State contexts
  NSBezierPath *state_contexts = nil;
  if (d["state_contexts"].table_entries.size() > 0) {
    float sc_tri_size = 10.0;
    float sc_tri_height = sc_tri_size / 1.14;
    float tri_x = x + node_width - sc_tri_size * 1.6;
    float tri_y = y + node_height() - sc_tri_size * 0.6;
    state_contexts = [NSBezierPath bezierPath];
    [state_contexts moveToPoint:NSMakePoint(tri_x,                 tri_y)];
    [state_contexts lineToPoint:NSMakePoint(tri_x + sc_tri_size/2, tri_y - sc_tri_height)];
    [state_contexts lineToPoint:NSMakePoint(tri_x + sc_tri_size,   tri_y)];
    [state_contexts closePath];
  }

  // Draw
  [[NSColor whiteColor] set];
  [path_main fill];

  [node_color set];
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

  if (state_contexts) {
    [node_color set];
    [state_contexts fill];
  }

  // Child connectors
  [[NSColor blackColor] set];
  int n_children_to_draw = n_children(&d) + (extra_child_connector ? 1 : 0);
  for (int i=0; i < n_children_to_draw; ++i) {
    NSPoint p = attachmentCoord_Child_forNode(&d, i);
    p = add_points(p, scroll);
    p = add_points(p, {-node_half_circle_size.x, -node_half_circle_size.y});
    path_ac_parent = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x, p.y, node_circle_size, node_circle_size)];
    [path_ac_parent fill];
  }
}

void drawConnection(NSPoint child_cnxn_pos, NSPoint parent_cnxn_pos, NSPoint scroll, bool inFlight, bool forbidden = false, bool attached = false) {
  NSBezierPath *path = [NSBezierPath bezierPath];

  child_cnxn_pos  = add_points(child_cnxn_pos, scroll);
  parent_cnxn_pos = add_points(parent_cnxn_pos, scroll);

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

#include "DiatomSerialization.h"

-(void)drawSubtree:(Diatom)t {
  std::vector<NSPoint> connections;

  t.recurse([&](std::string name, Diatom &n) {
    if (!is_node_diatom(&n)) {
      return;
    }

    UID uid = n["uid"].number_value;
    UID uid__selected_node = DOCW.selectedNode;

    bool is_selected = uid == uid__selected_node;
    bool is_hovered  = uid == hoveredNode;
    bool extra_child_connector = shouldDrawExtraChildConnector(&n, hoveredNode, ifc);

    drawNode(n, scroll, is_selected, is_hovered, false, extra_child_connector);

    // Save child connections to connections vector
    for (int i=0; i < n["children"].table_entries.size(); ++i) {
      Diatom &child = n["children"].table_entries[i].item;
      UID uid__child = child["uid"].number_value;

      bool skip_connection_because_inflight = (
        (ifc.type == InFlightConnection::FromParent &&
        ifc.fromNode == uid &&
        ifc.i__child == i)
        ||
        (ifc.type == InFlightConnection::FromChild &&
        ifc.fromNode == uid__child &&
        ifc.i__child == i)
      );
      if (skip_connection_because_inflight) {
        continue;
      }

      // For FromChild connections, shuffle parent's child-connector indices
      int j = i;
      bool inflight_from_child = (
        ifc.type == InFlightConnection::FromChild &&
        is_hovered &&
        ifc.i__temporary != -1
      );
      if (inflight_from_child) {
        if (ifc.toNode_prev == uid) {
          if (i < ifc.i__child && i >= ifc.i__temporary) {
            ++j;
          }
          else if (i > ifc.i__child && ifc.i__temporary >= i) {
            --j;
          }
        }
        else {
          if (i >= ifc.i__temporary) {
            ++j;
          }
        }
      }

      connections.push_back(attachmentCoord_Parent_forNode(&child));
      connections.push_back(attachmentCoord_Child_forNode(&n, j));
    }
  }, true);

  for (int i=0; i < connections.size(); i += 2) {
    drawConnection(connections[i], connections[i+1], scroll, false);
  }
}

-(void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  self.layer.backgroundColor = view_background_color(dark_mode(self)).CGColor;

  if (!laidOut) {
    [self layOutTree];
  }

  for (auto t : [DOCW getTree]) {
    [self drawSubtree:t];
  }

  // Draw in-flight connection
  if (ifc.type == InFlightConnection::FromChild) {
    drawConnection(
      attachmentCoord_Parent_forNode(&[DOCW getNode:ifc.fromNode]),
      ifc.currentPosition,
      scroll,
      true,
      ifc_forbidden,
      ifc_attached
    );
  }
  if (ifc.type == InFlightConnection::FromParent) {
    drawConnection(
      attachmentCoord_Child_forNode(&[DOCW getNode:ifc.fromNode], ifc.i__child),
      ifc.currentPosition,
      scroll,
      true,
      ifc_forbidden,
      ifc_attached
    );
  }
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


// Event coord conversion
// ---------------------------

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


// Events
// ---------------------------

-(void)mouseDown:(NSEvent*)ev {
  NSPoint pos = [self convertedPointForEvent:ev];
  hoveredNode = [DOCW nodeAtPoint:pos nodeWidth:node_width nodeHeight:node_height()];

  if (hoveredNode == NotFound) {
    [DOCW setSelectedNode:NotFound];
    [self endMouseDrag];
    DISP;
    return;
  }

  if ([DOCW containsUnknownNodes]) {
    putUpError(@"Unknown node types", @"The document contains nodes with definitions that failed to load. Resolve this before editing the tree.");
    return;
  }

  [DOCW setSelectedNode:hoveredNode];
  Diatom &d = [DOCW getNode:hoveredNode];

  int i__child = childConnector(&d, pos, hoveredNode, ifc);
  bool child_connector = i__child != -1;
  bool parent_connector = isOverParentConnector(&d, pos);
  UIDParentSearchResult parent = find_node_parent([DOCW getTree], hoveredNode);

  if (parent_connector) {
    // If an orphan, begin FromChild connection from selected node
    if (parent.uid == NotFound) {
      ifc = {
        InFlightConnection::FromChild,
        hoveredNode,
        NotFound,
        pos,
        -1,
        -1,
      };
    }

    // If has existing parent, begin FromParent connection
    else {
      ifc = {
        InFlightConnection::FromParent,
        parent.uid,
        hoveredNode,
        pos,
        key_string_to_number(parent.child_name, "n"),
      };
    }
  }

  else if (child_connector) {
    // Begin new FromParent connection
    int cur_children = n_children(&d);
    if (i__child >= cur_children) {
      ifc = {
        InFlightConnection::FromParent,
        hoveredNode,
        NotFound,
        pos,
        i__child,
        -1,
      };
    }

    // Edit existing FromChild connection
    else {
      UID uid__child = d["children"][numeric_key_string("n", i__child)]["uid"].number_value;
      ifc = {
        InFlightConnection::FromChild,
        uid__child,
        hoveredNode,
        pos,
        i__child,
        -1,
      };
    }
  }

  [self startMouseDragAt:pos];
  DISP;
}

-(void)mouseUp:(NSEvent*)ev {
  if (ifc.type == InFlightConnection::FromChild) {
    [self endDrag_ConnectionFromChild:ev];
  }
  else if (ifc.type == InFlightConnection::FromParent) {
    [self endDrag_ConnectionFromParent:ev];
  }

  [self endMouseDrag];
}

-(void)mouseMoved:(NSEvent*)ev {
  NSPoint p = [self convertedPointForEvent:ev];
  hoveredNode = [DOCW nodeAtPoint:p nodeWidth:node_width nodeHeight:node_height()];
  DISP;
}

-(void)keyDown:(NSEvent *)ev {
  unsigned int c = [ev.characters characterAtIndex:0];
  bool del = (c == 8 || c == 127);

  if (del && DOCW.selectedNode != NotFound) {
    Diatom d = [DOCW getNode:DOCW.selectedNode];
    [DOCW detach:DOCW.selectedNode];
    DOCW.selectedNode = NotFound;

    for (auto child : d["children"].table_entries) {
      [DOCW insert:child.item withParent:NotFound withIndex:-1];
    }
  }

  DISP;
}


// Drag
// ---------------------------

-(void)startMouseDragAt:(NSPoint)p {
  SEL sel = @selector(dragCB_MoveNode:);

  if (ifc.type == InFlightConnection::FromChild) {
    sel = @selector(dragCB_ConnectionFromChild:);
  }
  else if (ifc.type == InFlightConnection::FromParent) {
    sel = @selector(dragCB_ConnectionFromParent:);
  }

  dragTimer = [NSTimer scheduledTimerWithTimeInterval:0.04 target:self selector:sel userInfo:nil repeats:YES];
  dragInitial = p;
}

-(void)endMouseDrag {
  [dragTimer invalidate];
  ifc.type = InFlightConnection::None;
  DISP;
}

-(void)dragCB_MoveNode:(NSEvent*)ev {
  if (DOCW.selectedNode == NotFound) {
    [dragTimer invalidate];
    return;
  }

  NSPoint p = [self convertCurrentMouseLocation];
  NSPoint delta = {
    p.x - dragInitial.x,
    p.y - dragInitial.y
  };
  dragInitial = p;

  Diatom &n = [DOCW getNode:DOCW.selectedNode];
  n["posX"] = n["posX"].number_value + delta.x;
  n["posY"] = n["posY"].number_value + delta.y;

  DISP;
}

-(void)dragCB_ConnectionFromChild:(NSEvent*)ev {
  NSPoint p = [self convertCurrentMouseLocation];
  ifc.currentPosition = p;

  ifc_attached = false;
  ifc_forbidden = false;
  ifc.i__temporary = -1;

  hoveredNode = [DOCW nodeAtPoint:p nodeWidth:node_width nodeHeight:node_height()];

  if (hoveredNode == NotFound || hoveredNode == ifc.fromNode) {
    DISP;
    return;
  }

  Diatom d__hovered = [DOCW getNode:hoveredNode];

  int hovered_child_ind = childConnector(&d__hovered, p, hoveredNode, ifc);
  if (hovered_child_ind > -1) {
    ifc.currentPosition = attachmentCoord_Child_forNode(&d__hovered, hovered_child_ind);

    UIDParentSearchResult parent = find_node_parent([DOCW getTree], ifc.fromNode);
    bool is_existing_parent = parent.uid != NotFound && parent.uid == hoveredNode;

    int max_children = d__hovered["maxChildren"].number_value;
    bool forbidden_because_at_capacity = !is_existing_parent && max_children != -1 && n_children(&d__hovered) >= max_children;
    bool forbidden_because_circular    = !is_existing_parent && is_ancestor([DOCW getTree], ifc.fromNode, hoveredNode);

    ifc_forbidden = forbidden_because_at_capacity || forbidden_because_circular;
    if (!ifc_forbidden) {
      ifc_attached = true;
      ifc.i__temporary = hovered_child_ind;
    }
  }

  DISP;
}

-(void)dragCB_ConnectionFromParent:(NSEvent*)ev {
  NSPoint p = [self convertCurrentMouseLocation];
  ifc.currentPosition = p;

  ifc_forbidden = false;
  ifc_attached = false;
  hoveredNode = [DOCW nodeAtPoint:p nodeWidth:node_width nodeHeight:node_height()];

  if (hoveredNode == NotFound || hoveredNode == ifc.fromNode) {
    DISP;
    return;
  }

  Diatom &d__hovered = [DOCW getNode:hoveredNode];

  if (isOverParentConnector(&d__hovered, p)) {
    ifc.currentPosition = attachmentCoord_Parent_forNode(&d__hovered);
    ifc_attached = true;

    auto hov_parent = find_node_parent([DOCW getTree], hoveredNode);
    bool ifc_leaves_connection_unchanged =
      hov_parent.uid != NotFound &&
      hov_parent.uid == ifc.fromNode &&
      ifc.toNode_prev == hoveredNode;

    bool forbidden_because_circular = is_ancestor([DOCW getTree], hoveredNode, ifc.fromNode);
    bool forbidden_because_target_has_parent = hov_parent.uid != NotFound && !ifc_leaves_connection_unchanged;

    ifc_forbidden = forbidden_because_circular || forbidden_because_target_has_parent;
  }

  DISP;
}

-(void)endDrag_ConnectionFromChild:(NSEvent*)ev {
  NSPoint p = [self convertedPointForEvent:ev];
  hoveredNode = [DOCW nodeAtPoint:p nodeWidth:node_width nodeHeight:node_height()];
  Diatom copy = [DOCW getNode:ifc.fromNode];

  if (hoveredNode == NotFound && ifc.toNode_prev != NotFound) {
    [DOCW detach:ifc.fromNode];
    [DOCW insert:copy withParent:NotFound withIndex:-1];
    return;
  }

  Diatom &d__hovered = [DOCW getNode:hoveredNode];
  int i__child = childConnector(&d__hovered, p, hoveredNode, ifc);
  int max_children = d__hovered["maxChildren"].number_value;

  if (i__child == -1) {
    return;
  }
  if (hoveredNode == ifc.toNode_prev && i__child == ifc.i__child) {
    return;
  }
  if (max_children != -1 && n_children(&d__hovered) >= max_children) {
    return;
  }
  if (is_ancestor([DOCW getTree], ifc.fromNode, hoveredNode)) {
    return;
  }

  [DOCW detach:ifc.fromNode];
  [DOCW insert:copy withParent:hoveredNode withIndex:i__child];
}

-(void)endDrag_ConnectionFromParent:(NSEvent*)ev {
  NSPoint p = [self convertedPointForEvent:ev];
  hoveredNode = [DOCW nodeAtPoint:p nodeWidth:node_width nodeHeight:node_height()];

  if (hoveredNode == NotFound && ifc.toNode_prev != NotFound) {
    Diatom copy = [DOCW getNode:ifc.toNode_prev];
    [DOCW detach:ifc.toNode_prev];
    [DOCW insert:copy withParent:NotFound withIndex:-1];
    return;
  }

  Diatom &d__hovered = [DOCW getNode:hoveredNode];

  if (!isOverParentConnector(&d__hovered, p)) {
    return;
  }
  if (hoveredNode == ifc.toNode_prev) {
    return;
  }
  UIDParentSearchResult parent = find_node_parent([DOCW getTree], hoveredNode);
  if (parent.uid != NotFound) {  // Target node already has a parent
    return;
  }
  if (is_ancestor([DOCW getTree], hoveredNode, ifc.fromNode)) {
    return;
  }

  Diatom copy = d__hovered;
  [DOCW detach:hoveredNode];
  [DOCW insert:copy withParent:ifc.fromNode withIndex:ifc.i__child];
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];
  return [pb.types containsObject:NSPasteboardTypeString] ? NSDragOperationCopy : NSDragOperationNone;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSPasteboard *pb = [sender draggingPasteboard];

  if ([pb.types containsObject:NSPasteboardTypeString]) {
    if ([DOCW containsUnknownNodes]) {
      putUpError(@"Unknown node types", @"The document contains nodes with definitions that failed to load. Resolve this before editing the tree.");
      return YES;
    }

    std::string type = [[pb stringForType:NSPasteboardTypeString] UTF8String];

    NSPoint p = [self convertedPoint:[sender draggingLocation]];
    p.x -= node_width / 2;
    p.y -= node_height() / 2;

    [DOCW insert:[DOCW mkNodeOfType:type atPos:p] withParent:NotFound withIndex:-1];
    DISP;
  }

  return YES;
}


@end

