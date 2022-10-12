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

static NSString* const kDiscoverFeaturedEmojiPrefKey = @"FeaturedEmoji";

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

- (void) setupFeatured
{
	NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:kDiscoverFeaturedEmojiPrefKey];
	if (s.length == 0) {
		// first time, we won't have a random string saved, just use this
		s = @"📷📚☕️";
	}

	[self.popupButton addItemWithTitle:s];

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
	
	// save this featured emoji string for next time
	if (popup_title.length > 0) {
		[[NSUserDefaults standardUserDefaults] setObject:popup_title forKey:kDiscoverFeaturedEmojiPrefKey];
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
	RFDispatchSeconds (2.0, ^{
		[self.spinner stopAnimation:nil];
	});
}

- (void) setupTagmoji
{
	[self.popupButton removeAllItems];
	[self setupFeatured];

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

- (IBAction) showSearch:(id)sender
{
	if (self.searchView.superview != nil) {
		[self.searchView removeFromSuperview];
	}
	
	CGRect r = self.headerView.frame;
	self.searchView.frame = r;
	self.searchView.alphaValue = 0.0;
	self.searchView.hidden = NO;
	[self.headerView.superview addSubview:self.searchView];

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		self.searchView.animator.alphaValue = 1.0;
		self.headerView.animator.alphaValue = 0.0;
	} completionHandler:^{
		[self.searchField becomeFirstResponder];
	}];
}

- (IBAction) hideSearch:(id)sender
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		self.searchView.animator.alphaValue = 0.0;
		self.headerView.animator.alphaValue = 1.0;
	} completionHandler:^{
		self.searchView.hidden = YES;
	}];
}

@end
