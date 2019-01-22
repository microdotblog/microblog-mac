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
#import "RFInstagramController.h"
#import "RFPhotoZoomController.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFMacros.h"
#import "SAMKeychain.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "RFAccount.h"
#import "UUString.h"
#import "NSAlert+Extras.h"
#import "RFAutoCompleteCache.h"
#import "RFUserCache.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@implementation RFAppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	[self removeSandboxedContainer];
	
	[self setupDefaults];
	[self setupCrashlytics];
	[self setupNotifications];
	[self setupAppearance];
	[self setupURLs];
	[self setupFollowerAutoComplete];
	[self showTimelineOrWelcome];
}

- (void) applicationDidBecomeActive:(NSNotification *)notification
{
	[self showMainWindow:nil];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[self showMainWindow:nil];
	return YES;
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
	else if ([url.host isEqualToString:@"photo"]) {
		NSString* photo_url = [url.path substringFromIndex:1];
		[self showPhotoWithURL:photo_url];
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
	else if ([url.host isEqualToString:@"post"]) {
		NSString* text = [[[url absoluteString] uuFindQueryStringArg:@"text"] uuUrlDecoded];
		[self showNewPostWithText:text];
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

- (void) showTimelineOrWelcome
{
	BOOL show_timeline = NO;
	
	NSString* username = [RFSettings stringForKey:kAccountUsername];
	if (username) {
		NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];
		if (token) {
			show_timeline = YES;
			[self verifyAppToken:token];
		}
	}
	
	if (!show_timeline) {
		self.welcomeController = [[RFWelcomeController alloc] init];
		[self.welcomeController showWindow:nil];
	}
}

- (void) setupDefaults
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ kTextSizePrefKey: @(kTextSizeMedium) }];
	[RFSettings migrateSettings];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPhotoURLNotification:) name:kOpenPhotoURLNotification object:nil];
}

- (void) setupAppearance
{
	[[NSApplication sharedApplication] addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:NULL];
}

- (void) setupURLs
{
	NSAppleEventManager* manager = [NSAppleEventManager sharedAppleEventManager];
	[manager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void) setupFollowerAutoComplete
{
	RFAccount* account = [RFSettings defaultAccount];
	NSString* username = [account username];

	if (username == nil) {
		return;
	}
	username = [username stringByReplacingOccurrencesOfString:@"@" withString:@""];
	
	NSString* path = [NSString stringWithFormat:@"/users/following/%@", username];
	RFClient* client = [[RFClient alloc] initWithPath:path];
	[client getWithQueryArguments:nil completion:^(UUHttpResponse *response)
	 {
		 // We didn't get a valid response...
		 if (response.httpResponse.statusCode < 200 || response.httpResponse.statusCode > 299)
		 {
			 return;
		 }
		 
		 NSArray* array = response.parsedResponse;
		 if (array && [array isKindOfClass:[NSArray class]])
		 {
			 for (NSDictionary* dictionary in array)
			 {
				 NSString* username = dictionary[@"username"];
				 if (username)
				 {
					 [RFAutoCompleteCache addAutoCompleteString:username];
				 }
			 }
		 }
	 }];
}

- (void) observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDarkModeAppearanceDidChangeNotification object:self];
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

- (IBAction) importInstagram:(id)sender
{
	if (self.instagramController) {
		[self.instagramController close];
		self.instagramController = nil;
	}

	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.message = @"Unzip your Instagram archive download and select the media.json file.";
	panel.allowedFileTypes = @[ @"json" ];
	NSModalResponse response = [panel runModal];
	if (response == NSModalResponseOK) {
		NSURL* url = panel.URL;
		self.instagramController = [[RFInstagramController alloc] initWithFile:url.path];
		[self.instagramController showWindow:nil];
	}
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

- (void) showPhotoWithURL:(NSString *)photoURL
{
	NSLog (@"photo clicked: %@", photoURL);
	RFPhotoZoomController* controller = [[RFPhotoZoomController alloc] initWithURL:photoURL];
	[controller showWindow:nil];
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

- (void) openPhotoURLNotification:(NSNotification *)notification
{
	NSURL* url = [notification.userInfo objectForKey:kOpenPhotoURLKey];
	[self showPhotoWithURL:url.absoluteString];
}

- (void) showOptionsMenuWithPostID:(NSString *)postID
{
	[self.timelineController showOptionsMenuWithPostID:postID];
}

- (void) showProfileWithUsername:(NSString *)username
{
	[self.timelineController showProfileWithUsername:username];
}

- (void) loadTimelineWithToken:(NSString *)token account:(RFAccount *)account
{
	[SAMKeychain setPassword:token forService:@"Micro.blog" account:account.username];
	
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
		if (response.parsedResponse == nil) {
			RFDispatchMainAsync (^{
			});
		}
		else if (error) {
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
			NSString* default_site = [response.parsedResponse objectForKey:@"default_site"];
			
			RFAccount* a = [[RFAccount alloc] init];
			a.username = username;
			[RFSettings addAccount:a];
			
			[RFSettings setString:full_name forKey:kAccountFullName account:a];
			[RFSettings setString:username forKey:kAccountUsername account:a];
			[RFSettings setString:default_site forKey:kAccountDefaultSite account:a];
			[RFSettings setString:email forKey:kAccountEmail account:a];
			[RFSettings setString:gravatar_url forKey:kAccountGravatarURL account:a];
			[RFSettings setBool:[has_site boolValue] forKey:kHasSnippetsBlog account:a];
			[RFSettings setBool:[is_fullaccess boolValue] forKey:kIsFullAccess account:a];
		
			RFDispatchMainAsync (^{
				[self loadTimelineWithToken:token account:a];
				[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshAccountsNotification object:self];
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
	
	NSString* saved_state = [RFSettings stringForKey:kExternalMicropubState];
	NSString* saved_endpoint = [RFSettings stringForKey:kExternalMicropubTokenEndpoint];
	
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
						[RFSettings setString:me forKey:kExternalMicropubMe];
						[RFSettings setBool:YES forKey:kExternalBlogIsPreferred];
						[SAMKeychain setPassword:access_token forService:@"ExternalMicropub" account:@"default"];
					}
					
					[self.prefsController showMessage:@"Micropub API settings have been updated."];
				}
			});
		}];
	}
}

- (void) showNewPostWithText:(NSString *)text
{
	[self.timelineController showPostWithText:text];
}

@end
