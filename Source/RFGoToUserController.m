//
//  RFGoToUserController.m
//  Micro.blog
//
//  Created by Manton Reece on 11/10/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFGoToUserController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"

@implementation RFGoToUserController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"GoToUser"];
	if (self) {
	}
	
	return self;
}

- (IBAction) cancel:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) go:(id)sender
{
	NSString* username = self.usernameField.stringValue;
	if ([username containsString:@"@"]) {
		username = [username stringByReplacingOccurrencesOfString:@"@" withString:@""];
	}

	if (username.length > 0) {
		[self.progressSpinner startAnimation:nil];

		RFClient* client = [[RFClient alloc] initWithFormat:@"/posts/%@", username];
		NSDictionary* args = @{};
		[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];

				if (response.httpError != nil) {
					NSBeep();
				}
				else {
					[[NSNotificationCenter defaultCenter] postNotificationName:kShowUserProfileNotification object:self userInfo:@{ kShowUserProfileUsernameKey: username }];
					[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
				}
			});
		}];
	}
}

@end
