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
	[self showTimeline:nil];
}

- (IBAction) showTimeline:(id)sender
{
	NSString* token = [[NSUserDefaults standardUserDefaults] objectForKey:@"SnippetsToken"];
	CGFloat pane_width = self.webView.bounds.size.width;
	NSInteger timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) showMentions:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (IBAction) showFavorites:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

@end
