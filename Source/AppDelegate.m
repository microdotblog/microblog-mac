//
//  AppDelegate.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "AppDelegate.h"

#import "RFTimelineController.h"
#import <Paddle/Paddle.h>
#import <Paddle/PaddleToolKit.h>

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	self.timelineController = [[RFTimelineController alloc] init];
	[self.timelineController showWindow:nil];

	Paddle *paddle = [Paddle sharedInstance];
	[paddle setProductId:@"502392"];
	[paddle setVendorId:@"12519"];
	[paddle setApiKey:@"c67351aa75de6888a5d0774d83de2cce"];

//	[[PaddleToolKit sharedInstance] presentHappinessViewWithSchedule:nil message:@"Are you happy with your experience so far?"];
	[[PaddleToolKit sharedInstance] presentEmailSubscribePromptWithSchedule:nil message:@"Thanks for downloading the app! If you love microblogging, subscribe to our list to get occasional news."];
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

@end
