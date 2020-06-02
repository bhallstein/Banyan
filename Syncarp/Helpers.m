#import <Foundation/Foundation.h>
#import "Helpers.h"

void putUpError(NSString *title, NSString *detail) {
    NSError *err = [NSError errorWithDomain:@"" code:1257
                                   userInfo:@{ NSLocalizedDescriptionKey: title,
                                               NSLocalizedRecoverySuggestionErrorKey: detail }];
    [[NSAlert alertWithError:err] runModal];
}
