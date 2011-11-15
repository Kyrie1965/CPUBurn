//
//  AppDelegate.m
//  CPUBurn
//
//  Created by Yuri Yuriev on 14.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/host_info.h>
#include <mach/mach_host.h>
#include <mach/task_info.h>
#include <mach/task.h>

@implementation AppDelegate

@synthesize window = _window;
@synthesize infoBox = _infoBox;
@synthesize sensorsBox = _sensorsBox;
@synthesize infoTextView = _infoTextView;
@synthesize sensorsTextView = _sensorsTextView;
@synthesize indicator = _indicator;
@synthesize statusTextField = _statusTextField;
@synthesize burnButton = _burnButton;

- (void)dealloc
{
    if (timer)
    {
        [timer invalidate];
        [timer release];
    }
    
    if (purgeTask) [purgeTask release];
    if (burnTask) [burnTask release];
    
    if (sensors) [sensors release];
    
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSProcessInfo processInfo] disableSuddenTermination];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(terminateNotification:)
                                                 name:NSTaskDidTerminateNotification
                                               object:nil];
}

- (void)awakeFromNib
{
    running = NO;
    
    sensors = [[CPUSensors alloc] init];
    
    [self.window center];
    [self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [self.window setLevel:NSScreenSaverWindowLevel];
    
    [self.infoBox setTitle:NSLocalizedString(@"InfoBoxTitle", @"")];
    [self.sensorsBox setTitle:NSLocalizedString(@"SensorsBoxTitle", @"")];
    
    [[self.infoTextView enclosingScrollView] setBorderType:NSNoBorder];
    [[self.infoTextView enclosingScrollView] setDrawsBackground:NO];
    [self.infoTextView setDrawsBackground:NO];
    
    [[self.sensorsTextView enclosingScrollView] setBorderType:NSNoBorder];
    [[self.sensorsTextView enclosingScrollView] setDrawsBackground:NO];
    [self.sensorsTextView setDrawsBackground:NO];

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
	[attributes setObject:[NSFont systemFontOfSize:10] forKey:NSFontAttributeName];
	[attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	NSAttributedString *aStr = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"InfoBoxText", @"") attributes:attributes];
	[[self.infoTextView textStorage] setAttributedString:aStr];
	[aStr release];
	[attributes release];
    
    [self setSensorsText];
    
    [self.indicator setDisplayedWhenStopped:NO];
    [self.statusTextField setStringValue:@""];
    [self.burnButton setTitle:NSLocalizedString(@"BurnButtonTitle", @"")];
    
    timer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerAction:) userInfo:nil repeats:YES] retain];
}

- (IBAction)burnAction:(id)sender
{
    if (running)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        if (purgeTask)
        {
            if ([purgeTask isRunning])[purgeTask terminate];
            [purgeTask release];
            purgeTask = nil;
        }
        
        if (burnTask)
        {
            if ([burnTask isRunning])[burnTask terminate];
            [burnTask release];
            burnTask = nil;
        }
        
        [self.statusTextField setStringValue:@""];
        [self.burnButton setTitle:NSLocalizedString(@"BurnButtonTitle", @"")];
        [self.indicator stopAnimation:self];
        running = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(terminateNotification:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:nil];
    }
    else
    {
        purgeTask = [[NSTask alloc] init];
        [purgeTask setLaunchPath:@"/usr/bin/purge"];
        
        [self.burnButton setTitle:NSLocalizedString(@"StopButtonTitle", @"")];
        [self.indicator startAnimation:self];
        [self.statusTextField setStringValue:NSLocalizedString(@"PurgeStatus", @"")];
        running = YES;
        
        @try
        {
            [purgeTask launch];
        }
        @catch (NSException *e)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:NSTaskDidTerminateNotification object:purgeTask];
        }
    }
}

- (void)setSensorsText
{
    NSArray *sensorsData = [sensors sensorsData];

    if ([sensorsData count] == 0)
    {
        NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
        [attributes setObject:[NSFont systemFontOfSize:14] forKey:NSFontAttributeName];
        [attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
        NSAttributedString *aStr = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"SensorsNotFound", @"") attributes:attributes];
        [[self.sensorsTextView textStorage] setAttributedString:aStr];
        [aStr release];
        [attributes release];    
        
        return;
    }
    
    NSMutableString *str = [NSMutableString string];
    
    NSNumberFormatter *formater = [[NSNumberFormatter alloc] init];
    [formater setNumberStyle:NSNumberFormatterDecimalStyle];
    [formater setMaximumFractionDigits:1];
    
    for (int i = 0; i < [sensorsData count]; i++)
    {
        NSNumber *currentTemperature = [[sensorsData objectAtIndex:i] objectForKey:@"currentTemperature"];
        NSString *key = [[sensorsData objectAtIndex:i] objectForKey:@"key"];
        NSNumber *maxTemperature = [[sensorsData objectAtIndex:i] objectForKey:@"maxTemperature"];
        
        NSString *tmpStr = [NSString stringWithFormat:NSLocalizedString(@"SensorTemperature", @""), key, [formater stringFromNumber:currentTemperature], [formater stringFromNumber:maxTemperature]];
        [str appendString:tmpStr];
        
        if (i != ([sensorsData count] - 1)) [str appendString:@"\n"];
    }
    
    [formater release];
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
	[attributes setObject:[NSFont systemFontOfSize:14] forKey:NSFontAttributeName];
	[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	NSAttributedString *aStr = [[NSAttributedString alloc] initWithString:str attributes:attributes];
	[[self.sensorsTextView textStorage] setAttributedString:aStr];
	[aStr release];
	[attributes release];    
}

- (void)timerAction:(NSTimer *)aTimer
{
    [sensors updateSensors];
    [self setSensorsText];
}

- (void)terminateNotification:(NSNotification *)aNotification
{
    if ([aNotification object] == purgeTask)
    {
        [purgeTask release];
        purgeTask = nil;
        
        NSString *inputPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"lininput"];
        NSString *inputStr = [NSString stringWithContentsOfFile:inputPath encoding:NSUTF8StringEncoding error:NULL];
        
        size_t length;
        int mib[2]; 
        int pagesize = 0;
        mib[0] = CTL_HW;
        mib[1] = HW_PAGESIZE;
        length = sizeof(pagesize);
        sysctl(mib, 2, &pagesize, &length, NULL, 0);
        
        vm_statistics_data_t vmstat;
        mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
        int64_t free = 512 * 1024 * 1024;
        
        if ((host_statistics (mach_host_self(), HOST_VM_INFO, (host_info_t) &vmstat, &count) == KERN_SUCCESS) && (pagesize != 0))
        {
            free =(int64_t)vmstat.free_count * (int64_t)pagesize * 0.8;
        }

        if (free < 512 * 1024 * 1024) free = 512 * 1024 * 1024;
        else if (free > 1536 * 1024 * 1024) free = 1536 * 1024 * 1024;
        
        int64_t problemSize = sqrt(free / 8);
        inputStr = [NSString stringWithFormat:inputStr, problemSize, problemSize];
        
        [self.statusTextField setStringValue:NSLocalizedString(@"BurnStatus", @"")];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *tmpInputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"lininput_burn"];
        [fileManager removeItemAtPath:tmpInputPath error:NULL];
        [inputStr writeToFile:tmpInputPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        burnTask = [[NSTask alloc] init];
        [burnTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"linpack_cd64"]];
        [burnTask setArguments:[NSArray arrayWithObject:tmpInputPath]];
        
        @try
        {
            [burnTask launch];
        }
        @catch (NSException *e)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:NSTaskDidTerminateNotification object:burnTask];
        }
    }
    else if ([aNotification object] == burnTask)
    {
        [burnTask release];
        burnTask = nil;

        [self.statusTextField setStringValue:@""];
        [self.burnButton setTitle:NSLocalizedString(@"BurnButtonTitle", @"")];
        [self.indicator stopAnimation:self];
        running = NO;
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (purgeTask)
    {
        if ([purgeTask isRunning])[purgeTask terminate];
        [purgeTask release];
        purgeTask = nil;
    }
    
    if (burnTask)
    {
        if ([burnTask isRunning])[burnTask terminate];
        [burnTask release];
        burnTask = nil;
    }

    return NSTerminateNow;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

@end
