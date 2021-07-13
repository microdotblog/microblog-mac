//
//  RFDiscoverController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/13/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFDiscoverController.h"

#import "RFClient.h"
#import "RFMacros.h"
#import "NSAppearance+Extras.h"

@implementation RFDiscoverController

- (instancetype) init
{
	self = [super initWithNibName:@"Discover" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self setupWebView];
	[self setupTagmoji];
	
	if (self.tagmoji.count == 0) {
		[self fetchTagmoji];
	}
}

- (void) setupWebView
{
	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}

	NSString* url = @"https://micro.blog/hybrid/discover";
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (void) setupTagmoji
{
}

- (void) fetchTagmoji
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/discover"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse *response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMain (^{
				self.tagmoji = [[response.parsedResponse objectForKey:@"_microblog"] objectForKey:@"tagmoji"];
				[self setupTagmoji];
			});
		}
	}];
}

@end
