//
//  RFTopicController.m
//  Snippets
//
//  Created by Manton Reece on 1/8/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFTopicController.h"

#import "RFConstants.h"
#import "NSAppearance+Extras.h"

@implementation RFTopicController

- (instancetype) initWithTopic:(NSString *)topic
{
	self = [super initWithNibName:@"Topic" bundle:nil];
	if (self) {
		self.topic = topic;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	self.topicField.stringValue = self.topic;

	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/discover/%@", self.topic];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

@end
