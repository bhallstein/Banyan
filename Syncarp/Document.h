#import <Cocoa/Cocoa.h>

#define DISP [self setNeedsDisplay:YES]
#define index_in_vec(vec, n) int(n - &vec[0])

class Wrapper;

@interface Document : NSDocument <NSTextFieldDelegate>

@property (nonatomic) BOOL loaderWinOpen;

-(void*)getNodes;
-(Wrapper*)topNode;

-(void)detachNodeFromTree:(Wrapper*)n;
-(void)destroyNode:(Wrapper*)n;

-(Wrapper*)addNodeOfType:(NSString*)t at:(NSPoint)p;
-(void)makeNode:(Wrapper*)A childOf:(Wrapper*)B atIndex:(int)i;

-(BOOL)nodeIsOrphan:(Wrapper*)n;
-(BOOL)node:(Wrapper*)A isAncestorOf:(Wrapper*)B;
-(Wrapper*)parentOfNode:(Wrapper*)n;

-(void)setSelectedNode:(Wrapper*)n;

-(void*)getAllNodeDefs;
    // The vector returned by this is dynamically allocated
    // and must be freed by the caller

-(void*)getDefinitionFiles;

@end

