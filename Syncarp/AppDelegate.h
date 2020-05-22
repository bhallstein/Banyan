//
//  AppDelegate.h
//  Syncarp
//
//  Created by Ben on 23/03/2015.
//  Copyright (c) 2015 Ben. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class Diatom;

@interface AppDelegate : NSObject <NSApplicationDelegate>

-(Diatom)getNodeWithType:(const char *)type;
-(void*)builtInNodes;

@end

