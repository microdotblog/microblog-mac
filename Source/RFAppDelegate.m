//
//  AppDelegate.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFAppDelegate.h"

#import "RFTimelineController.h"
#import "RFWelcomeController.h"
#import "RFPreferencesController.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFMacros.h"
#import "SAMKeychain.h"
#import "RFConstants.h"
#import "UUString.h"
#import "NSAlert+Extras.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@implementation RFAppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];
	if (token) {
		self.timelineController = [[RFTimelineController alloc] init];
		[self.timelineController showWindow:nil];
	}
	else {
		self.welcomeController = [[RFWelcomeController alloc] init];
		[self.welcomeController showWindow:nil];
	}
	
	[self removeSandboxedContainer];
	
	[self setupDefaults];
	[self setupCrashlytics];
	[self setupNotifications];
	[self setupURLs];
}

- (void) applicationDidBecomeActive:(NSNotification *)notification
{
	[self showMainWindow:nil];
}

// 10.13
// - (void) application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls

- (void) handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSURL* url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	[self handleURLs:@[ url ]];
}

- (void) handleURLs:(NSArray *)urls
{
	NSURL* url = [urls firstObject];
	NSString* param = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
	if ([url.host isEqualToString:@"open"]) {
		[self showOptionsMenuWithPostID:param];
	}
	else if ([url.host isEqualToString:@"user"]) {
		[self showProfileWithUsername:param];
	}
	else if ([url.host isEqualToString:@"conversation"]) {
//		[self showConversationWithPostID:param];
	}
	else if ([url.host isEqualToString:@"signin"]) {
		[self verifyAppToken:param];
	}
	else if ([url.host isEqualToString:@"micropub"]) {
		[self showMicropubWithURL:[url absoluteString]];
	}
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

- (void) removeSandboxedContainer
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSError* error = nil;
	NSURL* library_url = [fm URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
	if (error == nil) {
		NSURL* container_url = [library_url URLByAppendingPathComponent:@"Containers" isDirectory:YES];
		NSURL* microblog_url = [container_url URLByAppendingPathComponent:@"blog.micro.mac" isDirectory:YES];
		if (microblog_url && [fm fileExistsAtPath:microblog_url.path]) {
			// sanity check that we've found the right folder
			NSURL* data_url = [microblog_url URLByAppendingPathComponent:@"Data" isDirectory:YES];
			if (data_url && [fm fileExistsAtPath:data_url.path]) {
				[fm trashItemAtURL:microblog_url resultingItemURL:nil error:NULL];
			}
		}
	}
}

- (void) setupDefaults
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ kTextSizePrefKey: @(kTextSizeMedium) }];
}

- (void) setupCrashlytics
{
	[Fabric with:@[ CrashlyticsKit ]];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signOutNotification:) name:@"RFSignOut" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasUnselectedNotification:) name:kPostWasUnselectedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReplyPostNotification:) name:kShowReplyPostNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openMicroblogURLNotification:) name:kOpenMicroblogURLNotification object:nil];
}

- (void) setupURLs
{
	NSAppleEventManager* manager = [NSAppleEventManager sharedAppleEventManager];
	[manager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

#pragma mark -

- (IBAction) showMainWindow:(id)sender
{
	[self.timelineController showWindow:nil];
}

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

- (void) openMicroblogURLNotification:(NSNotification *)notification
{
	NSURL* url = [notification.userInfo objectForKey:kOpenMicroblogURLKey];
	[self handleURLs:@[ url ]];
}

- (void) showOptionsMenuWithPostID:(NSString *)postID
{
	[self.timelineController showOptionsMenuWithPostID:postID];
}

- (void) showProfileWithUsername:(NSString *)username
{
	[self.timelineController showProfileWithUsername:username];
}

- (void) loadTimelineWithToken:(NSString *)token
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	[SAMKeychain setPassword:token forService:@"Micro.blog" account:username];
	
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

- (void) showMicropubWithURL:(NSString *)url
{
	NSString* code = [[url uuFindQueryStringArg:@"code"] uuUrlDecoded];
	NSString* state = [[url uuFindQueryStringArg:@"state"] uuUrlDecoded];
	NSString* me = [[url uuFindQueryStringArg:@"me"] uuUrlDecoded];

	if (!code || !state || !me) {
		NSString* msg = [NSString stringWithFormat:@"Authorization \"code\", \"state\", or \"me\" parameters were missing."];
		[NSAlert rf_showOneButtonAlert:@"Micropub Error" message:msg button:@"OK" completionHandler:NULL];
		return;
	}
	
	NSString* saved_state = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalMicropubState"];
	NSString* saved_endpoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalMicropubTokenEndpoint"];
	
	if (![state isEqualToString:saved_state]) {
		[NSAlert rf_showOneButtonAlert:@"Micropub Error" message:@"Authorization state did not match." button:@"OK" completionHandler:NULL];
	}
	else {
		NSDictionary* info = @{
			@"grant_type": @"authorization_code",
			@"me": me,
			@"code": code,
			@"redirect_uri": @"https://micro.blog/micropub/redirect",
			@"client_id": @"https://micro.blog/",
			@"state": state
		};
		
		RFMicropub* mp = [[RFMicropub alloc] initWithURL:saved_endpoint];
		[mp postWithParams:info completion:^(UUHttpResponse* response) {
			RFDispatchMain (^{
				if ([response.parsedResponse isKindOfClass:[NSString class]]) {
					NSString* msg = response.parsedResponse;
					if (msg.length > 200) {
						msg = @"";
					}
					[NSAlert rf_showOneButtonAlert:@"Micropub Error" message:msg button:@"OK" completionHandler:NULL];
				}
				else {
					NSString* access_token = [response.parsedResponse objectForKey:@"access_token"];
					if (access_token == nil) {
						NSString* msg = [response.parsedResponse objectForKey:@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Micropub Error" message:msg button:@"OK" completionHandler:NULL];
					}
					else {
						[[NSUserDefaults standardUserDefaults] setObject:me forKey:@"ExternalMicropubMe"];
						[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ExternalBlogIsPreferred"];
						[SAMKeychain setPassword:access_token forService:@"ExternalMicropub" account:@"default"];
					}
					
					[self.prefsController showMessage:@"Micropub API settings have been updated."];
				}
			});
		}];
	}
}

@end
