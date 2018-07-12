//
//  RFFriendsController.m
//  Snippets
//
//  Created by Manton Reece on 10/15/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFFriendsController.h"

#import "RFConstants.h"

@implementation RFFriendsController

- (instancetype) initWithUsername:(NSString *)username
{
	self = [super initWithNibName:@"Friends" bundle:nil];
	if (self) {
		self.username = username;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/users/discover/%@", self.username];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

@end
