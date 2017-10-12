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
#import "RFPreferencesController.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "SSKeychain.h"
#import "RFConstants.h"

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] objectForKey:@"AccountUsername"]) {
		self.timelineController = [[RFTimelineController alloc] init];
		[self.timelineController showWindow:nil];
	}
	else {
		self.welcomeController = [[RFWelcomeController alloc] init];
		[self.welcomeController showWindow:nil];
	}
	
	[self setupNotifications];
}

- (void) application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls
{
	NSURL* url = [urls firstObject];
	NSString* param = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
	if ([url.host isEqualToString:@"open"]) {
		[self showOptionsMenuWithPostID:param];
	}
	else if ([url.host isEqualToString:@"user"]) {
//		[self showProfileWithUsername:param];
	}
	else if ([url.host isEqualToString:@"conversation"]) {
//		[self showConversationWithPostID:param];
	}
	else if ([url.host isEqualToString:@"signin"]) {
		[self verifyAppToken:param];
	}
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signOutNotification:) name:@"RFSignOut" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasUnselectedNotification:) name:kPostWasUnselectedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReplyPostNotification:) name:kShowReplyPostNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
}

#pragma mark -

- (IBAction) showPreferences:(id)sender
{
	if (!self.prefsController) {
		self.prefsController = [[RFPreferencesController alloc] init];
	}

	[self.prefsController showWindow:nil];
}

#pragma mark -

- (void) signOutNotification:(NSNotification *)notification
{
	[self.timelineController close];
	
	self.welcomeController = [[RFWelcomeController alloc] init];
	[self.welcomeController showWindow:nil];
}

- (void) postWasUnselectedNotification:(NSNotification *)notification
{
//	NSString* post_id = [notification.userInfo objectForKey:kShowReplyPostIDKey];
//	[self.timelineController setSelected:NO withPostID:post_id];
	
	[self showOptionsMenuWithPostID:nil];
}

- (void) showReplyPostNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kShowReplyPostIDKey];
	NSString* username = [notification.userInfo objectForKey:kShowReplyPostUsernameKey];

	[self.timelineController showReplyWithPostID:post_id username:username];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self.timelineController performClose:nil];
}

- (void) showOptionsMenuWithPostID:(NSString *)postID
{
	[self.timelineController showOptionsMenuWithPostID:postID];
}

- (void) loadTimelineWithToken:(NSString *)token
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	[SSKeychain setPassword:token forService:@"Micro.blog" account:username];
	
	[self.welcomeController close];
	self.welcomeController = nil;
	
	if (self.timelineController == nil) {
		self.timelineController = [[RFTimelineController alloc] init];
	}
	
	[self.timelineController showWindow:nil];
}

- (void) verifyAppToken:(NSString *)token
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/account/verify"];
	NSDictionary* args = @{
		@"token": token
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		NSString* error = [response.parsedResponse objectForKey:@"error"];
		if (error) {
			RFDispatchMainAsync ((^{
//				[Answers logLoginWithMethod:@"Token" success:@NO customAttributes:nil];
//				[self showMessage:[NSString stringWithFormat:@"Error signing in: %@", error]];
			}));
		}
		else {
			NSString* full_name = [response.parsedResponse objectForKey:@"full_name"];
			NSString* username = [response.parsedResponse objectForKey:@"username"];
			NSString* email = [response.parsedResponse objectForKey:@"email"];
			NSString* gravatar_url = [response.parsedResponse objectForKey:@"gravatar_url"];
			NSNumber* has_site = [response.parsedResponse objectForKey:@"has_site"];
			NSNumber* is_fullaccess = [response.parsedResponse objectForKey:@"is_fullaccess"];
			NSNumber* default_site = [response.parsedResponse objectForKey:@"default_site"];
			
			[[NSUserDefaults standardUserDefaults] setObject:full_name forKey:@"AccountFullName"];
			[[NSUserDefaults standardUserDefaults] setObject:username forKey:@"AccountUsername"];
			[[NSUserDefaults standardUserDefaults] setObject:default_site forKey:@"AccountDefaultSite"];
			[[NSUserDefaults standardUserDefaults] setObject:email forKey:@"AccountEmail"];
			[[NSUserDefaults standardUserDefaults] setObject:gravatar_url forKey:@"AccountGravatarURL"];
			[[NSUserDefaults standardUserDefaults] setBool:[has_site boolValue] forKey:@"HasSnippetsBlog"];
			[[NSUserDefaults standardUserDefaults] setBool:[is_fullaccess boolValue] forKey:@"IsFullAccess"];
		
			RFDispatchMainAsync (^{
//				[Answers logLoginWithMethod:@"Token" success:@YES customAttributes:nil];
				[self loadTimelineWithToken:token];
			});
		}
	}];
}

@end
