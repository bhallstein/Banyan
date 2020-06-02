#ifndef Helpers_h
#define Helpers_h

#import <Cocoa/Cocoa.h>

void putUpError(NSString *title, NSString *detail);

#define DOC ((Document*) \
  [[NSDocumentController sharedDocumentController] currentDocument])

#define DOCW ((Document*) \
  [[[self window] windowController] document])

#endif

