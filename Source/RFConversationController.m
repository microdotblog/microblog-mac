//
//  RFConversationController.m
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFConversationController.h"

#import "RFConstants.h"

@implementation RFConversationController

- (instancetype) initWithPostID:(NSString *)postID
{
	self = [super initWithNibName:@"Conversation" bundle:nil];
	if (self) {
		self.postID = postID;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/conversation/%@", self.postID];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

@end
