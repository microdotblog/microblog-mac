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

	self.headerField.stringValue = [NSString stringWithFormat:@"@%@", self.username];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/posts/%@", self.username];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self checkFollowing];
}

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

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

@end
