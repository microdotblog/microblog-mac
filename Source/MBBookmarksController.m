//
//  MBBookmarksController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBBookmarksController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "NSString+Extras.h"
#import "NSAppearance+Extras.h"

static NSString* const kHighlightsCountPrefKey = @"HighlightsCount";

@implementation MBBookmarksController

- (id) init
{
	self = [super initWithNibName:@"Bookmarks" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self setupWebView];
	[self setupHighlightsButton];
	
	[self fetchHighlights];
}

- (void) setupWebView
{
	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}
	
	NSString* url = @"https://micro.blog/hybrid/bookmarks";
	
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (void) setupHighlightsButton
{
	// we cache the last highlights count to avoid flickering between blank and new value
	NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:kHighlightsCountPrefKey];
	NSString* s;
	if (num == 1) {
		s = @"1 highlight";
		[self.highlightsCountButton setTitle:s];
	}
	else if (num > 1) {
		s = [NSString stringWithFormat:@"%ld highlights", (long)num];
		[self.highlightsCountButton setTitle:s];
	}
	else {
		self.highlightsCountButton.hidden = YES;
	}
}

- (void) fetchHighlights
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/bookmarks/highlights"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSDictionary* mb = [response.parsedResponse objectForKey:@"_microblog"];
			NSNumber* num = [mb objectForKey:@"count"];
			
			RFDispatchMainAsync ((^{
				self.highlightsCount = num;
				if ([num integerValue] > 0) {
					[[NSUserDefaults standardUserDefaults] setObject:num forKey:kHighlightsCountPrefKey];
					NSString* s;
					if ([num integerValue] == 1) {
						s = @"1 highlight";
					}
					else {
						s = [NSString stringWithFormat:@"%@ highlights", num];
					}
					[self.highlightsCountButton setTitle:s];
					self.highlightsCountButton.hidden = NO;
				}
				
				// then fetch tags
				[self fetchTags];
			}));
		}
	}];
}

- (void) fetchTags
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/bookmarks/tags?recent=1&count=10"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSArray class]]) {
			NSMutableArray* new_tags = [NSMutableArray array];

			for (NSString* tag_name in response.parsedResponse) {
				[new_tags addObject:tag_name];
			}

			RFDispatchMainAsync (^{
				// now that we have both highlights and tags, update bar
				if ((new_tags.count == 0) && (self.highlightsCount.integerValue == 0)) {
					[self hideHighlightsBar];
				}
				else {
					self.tags = new_tags;
					NSMenu* menu = self.tagsButton.menu;
					NSMenuItem* item;
					
					item = [menu addItemWithTitle:@"Recent Tags" action:NULL keyEquivalent:@""];
					[item setEnabled:NO];
					
					for (NSString* tag_name in self.tags) {
						[self.tagsButton addItemWithTitle:tag_name];
					}

					[menu addItem:[NSMenuItem separatorItem]];
					
					[self.tagsButton addItemWithTitle:@"All Tags"];
					item = [self.tagsButton lastItem];
					[item setRepresentedObject:@"all_tags"];

					self.tagsButton.hidden = NO;
				}
			});
		}
	}];
}

- (IBAction) showHighlights:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowHighlightsNotification object:self];
}

- (IBAction) selectTag:(id)sender
{
	NSMenuItem* item = [sender selectedItem];
	if ([[item representedObject] isEqualToString:@"all_tags"]) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://micro.blog/bookmarks/tags"]];
	}
	else {
		NSString* tag_name = item.title;
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/bookmarks?tag=%@", [tag_name rf_urlEncoded]];
		
		NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
		[[self.webView mainFrame] loadRequest:request];
	}
}

- (void) hideHighlightsBar
{
	self.highlightsTopConstraint.animator.constant = -35;
}

@end