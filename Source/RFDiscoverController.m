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
#import "RFConstants.h"
#import "NSAppearance+Extras.h"

@implementation RFDiscoverController

- (instancetype) init
{
	self = [super initWithNibName:@"Discover" bundle:nil];
	if (self) {
		self.selectedTopic = @"";
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
	if (self.selectedTopic.length > 0) {
		url = [url stringByAppendingFormat:@"/%@", self.selectedTopic];
	}
	
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	[self.spinner startAnimation:nil];
}

- (void) setupTagmoji
{
	[self.popupButton removeAllItems];
	
	NSMutableArray* featured_emoji = [NSMutableArray array];
	for (NSDictionary* info in self.tagmoji) {
		if ([[info objectForKey:@"is_featured"] boolValue]) {
			NSString* emoji = [info objectForKey:@"emoji"];
			[featured_emoji addObject:emoji];
		}
	}
	
	NSString* popup_title = @"";
	for (int i = 0; i < 3; i++) {
		NSUInteger index = arc4random_uniform((int)featured_emoji.count);
		if (featured_emoji.count > index) {
			NSString* emoji = [featured_emoji objectAtIndex:index];
			popup_title = [popup_title stringByAppendingString:emoji];
			[featured_emoji removeObject:emoji];
		}
	}
	[self.popupButton addItemWithTitle:popup_title];
	
	for (NSDictionary* info in self.tagmoji) {
		if ([[info objectForKey:@"is_featured"] boolValue]) {
			NSString* name = [info objectForKey:@"name"];
			NSString* title = [info objectForKey:@"title"];
			NSString* emoji = [info objectForKey:@"emoji"];
			
			NSString* s = [NSString stringWithFormat:@"%@ %@", emoji, title];
			[self.popupButton addItemWithTitle:s];
			
			NSMenuItem* item = [self.popupButton lastItem];
			[item setRepresentedObject:name];
		}
	}
	
	NSMenu* menu = self.popupButton.menu;
	[menu addItem:[NSMenuItem separatorItem]];
	
	[self.popupButton addItemWithTitle:@"Show More"];
	NSMenuItem* item = [self.popupButton lastItem];
	[item setRepresentedObject:@"more"];
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

- (IBAction) selectTagmoji:(id)sender
{
	NSMenuItem* item = [self.popupButton selectedItem];
	NSString* name = item.representedObject;
	NSString* title = item.title;
	
	if ([name isEqualToString:@"more"]) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://help.micro.blog/t/emoji-in-discover/34"]];
	}
	else {
		self.selectedTopic = name;
		[self setupWebView];
		
		NSString* s = [NSString stringWithFormat:@"Some recent posts for %@.", title];
		[self.statusField setStringValue:s];
	}
}

@end
