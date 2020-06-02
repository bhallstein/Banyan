#import "NodeDefLoadList.h"
#import "Document.h"
#import "AppDelegate.h"
#include "Banyan/GenericTree/Diatom/Diatom.h"
#include "NodeDefFile.h"
#include "Helpers.h"
#include <vector>
#include <map>

#define COL(r, g, b) [NSColor colorWithDeviceRed:r/255. green:g/255. blue:b/255. alpha:1]

@interface NodeDefLoadList () {
  std::vector<NodeDefFile> *fileList;
}

@end


@implementation NodeDefLoadList

-(instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {

  }
  return self;
}

-(instancetype)initWithDefList:(void *)list frame:(NSRect)f {
  fileList = (std::vector<NodeDefFile>*)list;
  return [self initWithFrame:f];
}

-(AppDelegate*)appDelegate {
  return (AppDelegate*)[NSApplication sharedApplication].delegate;
}

-(BOOL)isFlipped { return YES; }

-(void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  [[NSColor whiteColor] set];
  NSRectFill(self.bounds);

  // Get list of loaded node definition files from Document
  // - should supply file location, and nodes loaded or error statuts
  // - iterate over them and draw
  // - let user fix missing files
  // - also let user remove files (and unload the associated node defs)

  float text_xpos = 12;
  float text_yline = 22;
  float text_yinitial = 10;
  NSDictionary *attribs_bold = @{
                                NSFontAttributeName: [NSFont systemFontOfSize:14.],
                                NSForegroundColorAttributeName: [NSColor blackColor]
                                };
  NSDictionary *attribs_reg = @{
                               NSFontAttributeName: [NSFont systemFontOfSize:14.],
                               NSForegroundColorAttributeName: [NSColor blackColor]
                               };
  NSDictionary *attribs_err = @{
                                NSFontAttributeName: [NSFont systemFontOfSize:14.],
                                NSForegroundColorAttributeName: [NSColor redColor]
                                };


  [@"Loaded node definitions:" drawAtPoint:NSMakePoint(text_xpos, text_yinitial)
                            withAttributes:attribs_bold];

  if (fileList && fileList->size() > 0) {
      int i=0;
      for (auto f : *fileList) {
          NSString *path = [NSString stringWithFormat:@"• %s", f.path.c_str()];
          [path drawAtPoint:NSMakePoint(text_xpos, text_yinitial + text_yline * ++i)
             withAttributes:(f.succeeded ? attribs_reg : attribs_err)];
      }
  }

  else {
      [@"No files loaded" drawAtPoint:NSMakePoint(text_xpos, text_yinitial + text_yline) withAttributes:attribs_reg];
  }
}


@end

