//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

@implementation RFTimelineController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Timeline"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupTextView];
	[self setupWebView];
}

- (void) setupTextView
{
	self.textView.font = [NSFont systemFontOfSize:15 weight:NSFontWeightLight];
	self.textView.backgroundColor = [NSColor colorWithCalibratedWhite:0.973 alpha:1.000];
}

- (void) setupWebView
{
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://snippets.today/"]];
	[[self.webView mainFrame] loadRequest:request];
}

@end
