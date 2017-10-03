//
//  AppDelegate.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "AppDelegate.h"

#import "RFTimelineController.h"
#import "RFWelcomeController.h"

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"SnippetsToken"]) {
		self.timelineController = [[RFTimelineController alloc] init];
		[self.timelineController showWindow:nil];
	}
	else {
		self.welcomeController = [[RFWelcomeController alloc] init];
		[self.welcomeController showWindow:nil];
	}
}

- (void) application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls
{
	NSURL* url = [urls firstObject];
	NSString* param = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
	if ([url.host isEqualToString:@"open"]) {
//		[self showOptionsMenuWithPostID:param];
	}
	else if ([url.host isEqualToString:@"user"]) {
//		[self showProfileWithUsername:param];
	}
	else if ([url.host isEqualToString:@"conversation"]) {
//		[self showConversationWithPostID:param];
	}
	else if ([url.host isEqualToString:@"signin"]) {
		[self showSigninWithToken:param];
	}
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

#pragma mark -

- (void) showSigninWithToken:(NSString *)token
{
	// TODO: verify token and save name, etc.
	// TODO: switch to keychain for storing token

	[[NSUserDefaults standardUserDefaults] setObject:token forKey:@"SnippetsToken"];
	
	[self.welcomeController close];
	
	self.timelineController = [[RFTimelineController alloc] init];
	[self.timelineController showWindow:nil];
}

@end
