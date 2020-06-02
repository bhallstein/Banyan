//
//  DragDestView.m
//  Syncarp
//
//  Created by Ben on 26/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import "DragDestView.h"

@interface DragDestView ()

@property NSColor *bgColour;
@property NSColor *defaultBGColour;
@property NSColor *defaultTextColour;

@property (copy) DragTest_FileDropCallback cb;
@property NSArray *file_paths;

@end

@implementation DragDestView

-(void)setFileDropCallback:(DragTest_FileDropCallback)cb {
  self.cb = cb;
}

-(void)drawRect:(NSRect)dirtyRect {
  if (self.bgColour) { [self.bgColour set]; }
  else               { [self.defaultBGColour set]; }
  NSRectFill(self.bounds);
}

-(void)awakeFromNib {
  [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];

  self.defaultBGColour = [NSColor windowBackgroundColor];

  if (self.textField) {
    self.defaultTextColour = self.textField.textColor;
    self.textField_origStr = self.textField.stringValue;
  }
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  self.bgColour = [NSColor orangeColor];
  [self.textField setTextColor:[NSColor darkGrayColor]];
  [self setNeedsDisplay:YES];
  return NSDragOperationGeneric;
}

-(void)draggingExited:(id<NSDraggingInfo>)sender {
  self.bgColour = nil;
  [self.textField setTextColor:self.defaultTextColour];
  [self setNeedsDisplay:YES];
}

-(void)draggingEnded:(id<NSDraggingInfo>)sender {
  self.bgColour = nil;
  [self.textField setTextColor:self.defaultTextColour];
  [self setNeedsDisplay:YES];
}

-(BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
  return YES;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSArray *types = sender.draggingPasteboard.types;

  self.file_paths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
//  self.file_paths_filtered = [file_paths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
//    NSString *str = evaluatedObject;
//    bool is_cpp = [str hasSuffix:@".diatom"];
//    if (!is_cpp) printf("File '%s' ignored -- not C++\n", [str UTF8String]);
//    return is_cpp;
//  }]];

  if (![types containsObject:NSFilenamesPboardType]) {
    printf("DragDestView: No NSFilenamesPboardType items in pasteboard for drag operation\n");
    return NO;
  }

  self.textField.stringValue = @"Loading...";
  NSTimer *timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(runCallback:) userInfo:nil repeats:NO];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

  return YES;
}
-(void)concludeDragOperation:(id<NSDraggingInfo>)sender {

}

-(void)runCallback:(id)blah {
  if (self.cb && self.file_paths && self.file_paths.count > 0) {
    self.cb(self.file_paths);

    if (self.textField_origStr) {
      self.textField.stringValue = self.textField_origStr;
    }
  }
}


@end

