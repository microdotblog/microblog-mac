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

@implementation RFOptionsController

- (instancetype) initWithPostID:(NSString *)postID username:(NSString *)username popoverType:(RFOptionsPopoverType)popoverType
{
	self = [super initWithNibName:@"Options" bundle:nil];
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

	// ...
}

- (IBAction) reply:(id)sender
{
	[self sendUnselectedNotification];
	[self sendReplyNotification];
}

- (IBAction) favorite:(id)sender
{
	[self sendUnselectedNotification];
}

- (IBAction) conversation:(id)sender
{
	[self sendUnselectedNotification];
}

// favorite
// unfavorite
// conversation
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
