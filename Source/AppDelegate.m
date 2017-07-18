//
//  AppDelegate.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "AppDelegate.h"

#import "RFTimelineController.h"

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	self.timelineController = [[RFTimelineController alloc] init];
	[self.timelineController showWindow:nil];
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

@end
