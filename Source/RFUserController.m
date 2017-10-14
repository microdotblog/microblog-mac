//
//  RFUserController.m
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFUserController.h"

#import "RFConstants.h"

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
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

@end
