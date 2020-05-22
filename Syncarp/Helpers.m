//
//  Helpers.m
//  Syncarp
//
//  Created by Ben on 29/09/2015.
//  Copyright © 2015 Ben. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Helpers.h"

void putUpError(NSString *title, NSString *detail) {
    NSError *err = [NSError errorWithDomain:@"" code:1257
                                   userInfo:@{ NSLocalizedDescriptionKey: title,
                                               NSLocalizedRecoverySuggestionErrorKey: detail }];
    [[NSAlert alertWithError:err] runModal];
}
