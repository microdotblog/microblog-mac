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
				}
				else {
					self.followButton.hidden = NO;
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

//	self.blogAddressLabel.text = [authorInfo objectForKey:@"url"];
//	self.pathToBlog = [authorInfo objectForKey:@"url"];
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

@end
