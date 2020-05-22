//
//  NodeLoaderWinCtrlr.m
//  Syncarp
//
//  Created by Ben on 27/09/2015.
//  Copyright © 2015 Ben. All rights reserved.
//

#import "NodeLoaderWinCtrlr.h"
#import "DragDestView.h"
#import "NodeDefLoadList.h"
#import "Document.h"
//#include "Helpers.h"

@interface NodeLoaderWinCtrlr () {
    Document *doc;
}

@property IBOutlet NSTextField *loadStatusText;
@property IBOutlet DragDestView *dragDestView;
@property IBOutlet NSScrollView *view_nodedef_loadlist_container;
@property NodeDefLoadList *view_nodedef_loadlist;

@property (copy) DragTest_FileDropCallback cb;

@end


@implementation NodeLoaderWinCtrlr


-(instancetype)initWithDoc:(Document*)d {
    self = [super initWithWindowNibName:@"NodeLoaderWinCtrlr"];
    if (self) {
        doc = d;
    }
    return self;
}

-(void)setCB:(FileDropCallback)cb {
    self.cb = cb;
}

-(void)disp {
    [self.view_nodedef_loadlist setNeedsDisplay:YES];
}

-(void)awakeFromNib {
    self.dragDestView.textField = self.loadStatusText;
    [self.dragDestView setFileDropCallback:self.cb];
    self.dragDestView.textField_origStr = self.loadStatusText.stringValue;
    
    self.view_nodedef_loadlist = [[NodeDefLoadList alloc] initWithDefList:doc.getDefinitionFiles
                                                                    frame:self.view_nodedef_loadlist_container.frame];
    [self.view_nodedef_loadlist_container setDocumentView:self.view_nodedef_loadlist];
}

-(void)loadWindow {
    [super loadWindow];
    [self.window setBackgroundColor:[NSColor colorWithDeviceWhite:0.73 alpha:1]];
}

-(void)windowDidLoad {
    [super windowDidLoad];
}

-(void)showWindow:(id)sender {
    [super showWindow:sender];
}


@end
