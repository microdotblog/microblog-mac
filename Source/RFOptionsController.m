//
//  RFOptionsController.m
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFOptionsController.h"

#import "RFConstants.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "NSAppearance+Extras.h"

@implementation RFOptionsController

- (instancetype) initWithPostID:(NSString *)postID username:(NSString *)username popoverType:(RFOptionsPopoverType)popoverType
{
	if (popoverType == kOptionsPopoverWithUnfavorite) {
		self = [super initWithNibName:@"OptionsWithUnfavorite" bundle:nil];
	}
	else {
		self = [super initWithNibName:@"Options" bundle:nil];
	}
	
	if (self) {
		self.postID = postID;
		self.username = username;
		self.popoverType = popoverType;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupButtons];
}

- (void) setupButtons
{
	NSString* reply_s = @"options_reply";
	NSString* favorite_s = @"options_favorite";
	NSString* conversation_s = @"options_conversation";
	NSString* browser_s = @"options_safari";

	NSURL* example_url = [NSURL URLWithString:@"https://micro.blog/"];
	NSURL* app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:example_url];
	if ([app_url.lastPathComponent containsString:@"Chrome"]) {
		browser_s = @"options_chrome";
	}
	else if ([app_url.lastPathComponent containsString:@"Firefox"]) {
		browser_s = @"options_firefox";
	}
	
	if ([NSAppearance rf_isDarkMode]) {
		reply_s = [reply_s stringByAppendingString:@"_darkmode"];
		favorite_s = [favorite_s stringByAppendingString:@"_darkmode"];
		conversation_s = [conversation_s stringByAppendingString:@"_darkmode"];
		browser_s = [browser_s stringByAppendingString:@"_darkmode"];
	}
	
	self.replyButton.image = [NSImage imageNamed:reply_s];
	self.favoriteButton.image = [NSImage imageNamed:favorite_s];
	self.conversationButton.image = [NSImage imageNamed:conversation_s];
	self.browserButton.image = [NSImage imageNamed:browser_s];
}

#pragma mark -

- (IBAction) reply:(id)sender
{
	[self sendUnselectedNotification];
	[self sendReplyNotification];
}

- (IBAction) favorite:(id)sender
{
	[self sendUnselectedNotification];

	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/favorites"];
	NSDictionary* args = @{ @"id": self.postID };
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kPostWasFavoritedNotification object:self userInfo:@{ kPostNotificationPostIDKey: self.postID}];
		});
	}];
}

- (IBAction) unfavorite:(id)sender
{
	[self sendUnselectedNotification];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/posts/favorites/%@", self.postID];
	[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kPostWasUnfavoritedNotification object:self userInfo:@{ kPostNotificationPostIDKey: self.postID}];
		});
	}];
}

- (IBAction) conversation:(id)sender
{
	[self sendUnselectedNotification];

	[[NSNotificationCenter defaultCenter] postNotificationName:kShowConversationNotification object:self userInfo:@{ kPostNotificationPostIDKey: self.postID}];
}

// deletePost

- (IBAction) share:(id)sender
{	
	[[NSNotificationCenter defaultCenter] postNotificationName:kSharePostNotification object:self userInfo:@{ kSharePostIDKey: self.postID}];
}

- (void) sendReplyNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowReplyPostNotification object:self userInfo:@{
		kShowReplyPostIDKey: self.postID,
		kShowReplyPostUsernameKey: self.username
	}];
}

- (void) sendUnselectedNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPostWasUnselectedNotification object:self userInfo:@{
		kShowReplyPostIDKey: self.postID
	}];
}

@end
