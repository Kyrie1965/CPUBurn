//
//  AppDelegate.h
//  CPUBurn
//
//  Created by Yuri Yuriev on 14.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CPUSensors.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    CPUSensors *sensors;
    NSTimer *timer;
    
    NSTask *purgeTask;
    NSTask *burnTask;
    
    BOOL running;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSBox *infoBox;
@property (assign) IBOutlet NSBox *sensorsBox;
@property (assign) IBOutlet NSTextView *infoTextView;
@property (assign) IBOutlet NSTextView *sensorsTextView;
@property (assign) IBOutlet NSProgressIndicator *indicator;
@property (assign) IBOutlet NSTextField *statusTextField;
@property (assign) IBOutlet NSButton *burnButton;

- (IBAction)burnAction:(id)sender;

- (void)setSensorsText;

@end
