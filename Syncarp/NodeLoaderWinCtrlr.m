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

@interface NodeLoaderWinCtrlr ()

@property IBOutlet NSTextField *loadStatusText;
@property IBOutlet DragDestView *dragDestView;
@property IBOutlet NSScrollView *view_nodedef_loadlist_container;
@property NodeDefLoadList *view_nodedef_loadlist;


@property (copy) DragTest_FileDropCallback cb;

@end


@implementation NodeLoaderWinCtrlr

-(instancetype)init {
    self = [super initWithWindowNibName:@"NodeLoaderWinCtrlr"];
    if (self) {
        
    }
    return self;
}

-(void)setCB:(FileDropCallback)cb {
    self.cb = cb;
}

-(void)awakeFromNib {
    self.dragDestView.textField = self.loadStatusText;
    [self.dragDestView setFileDropCallback:self.cb];
    self.dragDestView.textField_origStr = self.loadStatusText.stringValue;
    
    self.view_nodedef_loadlist = [[NodeDefLoadList alloc] initWithFrame:self.view_nodedef_loadlist_container.frame];
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
