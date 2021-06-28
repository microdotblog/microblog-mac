//
//  RFUserController.m
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFUserController.h"

#import "RFConstants.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "NSAppearance+Extras.h"

@implementation RFUserController

- (instancetype) initWithUsername:(NSString *)username
{
	self = [super initWithNibName:@"User" bundle:nil];
	if (self) {
		self.username = username;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}

	[self checkFollowing];
	[self fetchUserInfo];
}

#pragma mark -

- (void) checkFollowing
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/users/is_following"];
	NSDictionary* args = @{
		@"username": self.username
	};
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			BOOL is_following = [[response.parsedResponse objectForKey:@"is_following"] boolValue];
			BOOL is_you = [[response.parsedResponse objectForKey:@"is_you"] boolValue];
			RFDispatchMain (^{
				if (is_you) {
					self.followButton.hidden = YES;
					self.optionsButton.hidden = YES;
				}
				else {
					self.followButton.hidden = NO;
					self.optionsButton.hidden = NO;
					[self setupFollowing:is_following];
				}
			});
		}
	}];
}

- (void) fetchUserInfo
{
    RFClient* client = [[RFClient alloc] initWithPath:[NSString stringWithFormat:@"/posts/%@", self.username]];
    [client getWithQueryArguments:nil completion:^(UUHttpResponse *response) {
		if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
            NSDictionary* userInfo = response.parsedResponse;
            if (userInfo) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateAppearanceFromDictionary:userInfo];
                    [self loadUserPosts];
                });
            }
        }
    }];
}

- (void) loadUserPosts
{
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/posts/%@", self.username];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (void) updateAppearanceFromDictionary:(NSDictionary*)userInfo
{
	NSDictionary* microblog_info = [userInfo objectForKey:@"_microblog"];
	NSDictionary* author_info = [userInfo objectForKey:@"author"];

	self.headerField.stringValue = [author_info objectForKey:@"name"];
	self.headerField.hidden = NO;

	NSString* s = [microblog_info objectForKey:@"bio"];
	if (s.length > 280) {
		s = [[s substringToIndex:280] stringByAppendingString:@"..."];
	}
	self.bioField.stringValue = s;
	self.bioField.hidden = NO;
	self.bioDivider.hidden = NO;
	
	if (self.bioField.stringValue.length == 0) {
		// effectively hide the unused space for the bio field
		self.bioSpacingConstraint.constant = 0;
	}

	NSInteger following_count = [[microblog_info objectForKey:@"discover_count"] intValue];
	if (following_count == 0) {
		self.followingUsersButton.title = @"";
		self.followingHeightConstraint.constant = 0;
	}
	else if (following_count == 1) {
		self.followingUsersButton.title = @"Following 1 user you aren't following";
	}
	else {
		self.followingUsersButton.title = [NSString stringWithFormat:@"Following %ld users you aren't following", (long)following_count];
	}
	
	self.followingUsersButton.hidden = NO;
	
	NSString* url = [author_info objectForKey:@"url"];
	if (url.length == 0) {
		url = [NSString stringWithFormat:@"https://micro.blog/%@", self.username];
	}
	[self.websiteButton setTitle:url];
	[self.websiteButton setHidden:NO];
	self.siteURL = url;
}

- (void) setupFollowing:(BOOL)isFollowing
{
	if (isFollowing) {
		self.followButton.title = @"Unfollow";
		self.followButton.action = @selector(unfollow:);
		self.followButton.target = self;
	}
	else {
		self.followButton.title = @"Follow";
		self.followButton.action = @selector(follow:);
		self.followButton.target = self;
	}
}

#pragma mark -

- (void) follow:(id)sender
{
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithPath:@"/users/follow"];
	NSDictionary* args = @{
		@"username": self.username
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMain (^{
			[self.progressSpinner stopAnimation:nil];
			[self setupFollowing:YES];
		});
	}];
}

- (void) unfollow:(id)sender
{
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithPath:@"/users/unfollow"];
	NSDictionary* args = @{
		@"username": self.username
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMain (^{
			[self.progressSpinner stopAnimation:nil];
			[self setupFollowing:NO];
		});
	}];
}

- (IBAction) showFollowing:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowUserFollowingNotification object:self userInfo:@{ kShowUserFollowingUsernameKey: self.username }];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

- (IBAction) showOptions:(id)sender
{
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Options"];

	NSString* s;
	NSMenuItem* item;
	
	s = [NSString stringWithFormat:@"Mute @%@", self.username];
	item = [[NSMenuItem alloc] initWithTitle:s action:@selector(muteUser:) keyEquivalent:@""];
	item.target = self;
	[menu addItem:item];

	s = [NSString stringWithFormat:@"Report @%@", self.username];
	item = [[NSMenuItem alloc] initWithTitle:s action:@selector(reportUser:) keyEquivalent:@""];
	item.target = self;
	[menu addItem:item];

	[menu popUpMenuPositioningItem:nil atLocation:[NSEvent mouseLocation] inView:nil];
}

- (IBAction) openSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:self.siteURL]];
}

- (void) muteUser:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/account/muting?username=%@", self.username];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (void) reportUser:(id)sender
{
	NSAlert* sheet = [[NSAlert alloc] init];

	sheet.messageText = [NSString stringWithFormat:@"Report @%@ to Micro.blog for review? ", self.username];
	sheet.informativeText = @"We'll look at this user's posts to determine if they violate our community guidelines.";

	[sheet addButtonWithTitle:@"Report"];
	[sheet addButtonWithTitle:@"Cancel"];
	[sheet addButtonWithTitle:@"Community Guidelines"];
	[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == 1000) {
			[self reportUserWithUsername:self.username];
		}
		else if (returnCode == 1002) {
			[self openCommunityGuidelines];
		}
	}];
}

- (void) reportUserWithUsername:(NSString *)username
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/users/report"];
	NSDictionary* args = @{
		@"username": username
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
	}];
}

- (void) openCommunityGuidelines
{
	NSString* url = @"https://help.micro.blog/2017/community-guidelines/";
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

@end
