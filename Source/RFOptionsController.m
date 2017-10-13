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
}

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
// share

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
