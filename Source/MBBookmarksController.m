//
//  MBBookmarksController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBBookmarksController.h"

#import "RFAppDelegate.h"
#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "RFSettings.h"
#import "NSString+Extras.h"
#import "NSAppearance+Extras.h"
#import "MBLinksController.h"
#import "MBHighlightsController.h"

typedef NS_ENUM(NSInteger, MBBookmarksTab) {
	MBBookmarksTabBookmarks,
	MBBookmarksTabHighlights,
	MBBookmarksTabLinks
};

@interface MBBookmarksController()
@property (strong, nonatomic) NSSegmentedControl* tabsControl;
@property (strong, nonatomic) MBLinksController* linksController;
@property (strong, nonatomic) MBHighlightsController* highlightsController;
@property (assign, nonatomic) MBBookmarksTab selectedTab;
@property (assign, nonatomic) BOOL loadingBookmarks;
@end

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

	[self setupTabs];
	[self hideCurrentTag];
	[self setupWebView];

	[self fetchTags];
}

- (void) setupNotifications
{
	[super setupNotifications];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectTagNotification:) name:kSelectTagNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshBookmarksNotification:) name:kRefreshBookmarksNotification object:nil];
}

- (void) setupWebView
{
	self.loadingBookmarks = YES;
	[self updateLoadingSidebarRow];
	self.selectedPostID = nil;
	if ([NSAppearance rf_isDarkMode]) {
		[self.webView setDrawsBackground:NO];
	}
	
	NSString* url = @"https://micro.blog/hybrid/bookmarks";
	if (self.currentTagField.stringValue.length > 0) {
		url = [url stringByAppendingFormat:@"?tag=%@", [self.currentTagField.stringValue rf_urlEncoded]];
	}
	
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
}

- (void) setupTabs
{
	self.tabsControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Bookmarks", @"Highlights", @"Links"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(selectTab:)];
	self.tabsControl.selectedSegment = MBBookmarksTabBookmarks;
	self.tabsControl.hidden = ![RFSettings isPremium];
	self.tabsControl.translatesAutoresizingMaskIntoConstraints = NO;
	NSView* bar = self.headerBox.contentView;
	[bar addSubview:self.tabsControl];
	[NSLayoutConstraint activateConstraints:@[
		[self.tabsControl.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:18],
		[self.tabsControl.centerYAnchor constraintEqualToAnchor:self.tagsButton.centerYAnchor],
		[self.tabsControl.trailingAnchor constraintLessThanOrEqualToAnchor:self.currentTagCloseButton.leadingAnchor constant:-12]
	]];
}

- (BOOL) showingBookmarks
{
	return self.selectedTab == MBBookmarksTabBookmarks;
}

- (void) hideCurrentTag
{
	self.currentTagField.stringValue = @"";
	[self updateTagControls];
}

- (void) updateTagControls
{
	BOOL has_tag = self.showingBookmarks && self.currentTagField.stringValue.length > 0;
	self.currentTagField.hidden = !has_tag;
	self.currentTagCloseButton.hidden = !has_tag;
	self.tagsButton.hidden = !self.showingBookmarks;
}

- (void) addContentController:(NSViewController *)controller
{
	[self addChildViewController:controller];
	NSView* content_view = controller.view;
	content_view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:content_view];
	[NSLayoutConstraint activateConstraints:@[
		[content_view.topAnchor constraintEqualToAnchor:self.webView.topAnchor],
		[content_view.bottomAnchor constraintEqualToAnchor:self.webView.bottomAnchor],
		[content_view.leadingAnchor constraintEqualToAnchor:self.webView.leadingAnchor],
		[content_view.trailingAnchor constraintEqualToAnchor:self.webView.trailingAnchor]
	]];
}

- (void) selectTab:(id)sender
{
	[self showTab:self.tabsControl.selectedSegment];
}

- (void) showTab:(MBBookmarksTab)tab
{
	if (![RFSettings isPremium]) {
		tab = MBBookmarksTabBookmarks;
	}

	__weak MBBookmarksController* weak_self = self;
	if (tab == MBBookmarksTabHighlights && self.highlightsController == nil) {
		self.highlightsController = [[MBHighlightsController alloc] init];
		self.highlightsController.loadingDidChange = ^{
			[weak_self updateLoadingSidebarRow];
		};
		[self addContentController:self.highlightsController];
	}
	else if (tab == MBBookmarksTabLinks && self.linksController == nil) {
		self.linksController = [[MBLinksController alloc] init];
		self.linksController.loadingDidChange = ^{
			[weak_self updateLoadingSidebarRow];
		};
		[self addContentController:self.linksController];
		[self.linksController reloadLinks];
	}

	self.selectedTab = tab;
	self.tabsControl.selectedSegment = tab;
	self.webView.hidden = !self.showingBookmarks;
	self.highlightsController.view.hidden = (tab != MBBookmarksTabHighlights);
	self.linksController.view.hidden = (tab != MBBookmarksTabLinks);
	[self updateTagControls];
	[self focusContent];
}

- (void) focusContent
{
	if (self.selectedTab == MBBookmarksTabHighlights) {
		[self.view.window makeFirstResponder:self.highlightsController.tableView];
	}
	else if (self.selectedTab == MBBookmarksTabLinks) {
		[self.linksController focusContent];
	}
	else {
		[self.view.window makeFirstResponder:self.webView];
	}
}

- (void) keyDown:(NSEvent *)event
{
	if (self.showingBookmarks) {
		[super keyDown:event];
	}
}

- (void) moveUp:(id)sender
{
	if (self.showingBookmarks) {
		[super moveUp:sender];
	}
}

- (void) moveDown:(id)sender
{
	if (self.showingBookmarks) {
		[super moveDown:sender];
	}
}

- (IBAction) reply:(id)sender
{
	if (self.showingBookmarks) {
		[super reply:sender];
	}
}

- (void) showHighlights
{
	[self showTab:MBBookmarksTabHighlights];
}

- (void) refresh
{
	if (self.selectedTab == MBBookmarksTabHighlights) {
		[self.highlightsController fetchHighlights];
	}
	else if (self.selectedTab == MBBookmarksTabLinks) {
		[self.linksController reloadLinks];
	}
	else {
		[self setupWebView];
		[self fetchTags];
	}
}

- (void) bookmarksDidFinishLoading
{
	self.loadingBookmarks = NO;
	[self updateLoadingSidebarRow];
}

- (void) updateLoadingSidebarRow
{
	if (self.view.window == nil) {
		return;
	}
	// The web page and native tabs can load at the same time.
	BOOL loading = self.loadingBookmarks || self.highlightsController.loading || self.linksController.loading;
	NSString* name = loading ? kTimelineDidStartLoading : kTimelineDidStopLoading;
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:@{
		kTimelineSidebarRowKey: @(kTimelineBookmarksSidebarRow)
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
				self.tags = new_tags;
				NSMenu* menu = self.tagsButton.menu;
				// Keep the popup's icon item, replacing the fetched menu entries on refresh.
				while (menu.numberOfItems > 1) {
					[menu removeItemAtIndex:1];
				}
				if (self.tags.count > 0) {
					NSMenuItem* heading = [menu addItemWithTitle:@"Recent Tags" action:NULL keyEquivalent:@""];
					heading.enabled = NO;
					for (NSString* tag_name in self.tags) {
						[self.tagsButton addItemWithTitle:tag_name];
					}
					[menu addItem:[NSMenuItem separatorItem]];
				}
				[self.tagsButton addItemWithTitle:@"All Tags"];
				NSMenuItem* item = self.tagsButton.lastItem;
				item.representedObject = @"all_tags";
				item.keyEquivalent = @"T";
				item.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;

				item = [menu addItemWithTitle:@"New Bookmark" action:@selector(newBookmark:) keyEquivalent:@"b"];
				item.target = [NSApp delegate];
				item.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
			});
		}
	}];
}

- (IBAction) selectTag:(id)sender
{
	[self showTab:MBBookmarksTabBookmarks];
	NSMenuItem* item = [sender selectedItem];
	if ([[item representedObject] isEqualToString:@"all_tags"]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kShowTagsNotification object:self];
	}
	else {
		[self selectTagWithName:item.title];
	}
}

- (IBAction) clearCurrentTag:(id)sender
{
	[self hideCurrentTag];
	[self setupWebView];
}

- (void) selectTagWithName:(NSString *)tagName
{
	[self showTab:MBBookmarksTabBookmarks];
	self.currentTagField.stringValue = tagName;
	[self updateTagControls];
	[self setupWebView];
}

- (void) selectTagNotification:(NSNotification *)notification
{
	NSString* t = [notification.userInfo objectForKey:kSelectTagNameKey];
	[self selectTagWithName:t];
}

- (void) refreshBookmarksNotification:(NSNotification *)notification
{
	[self setupWebView];
	if (self.linksController) {
		[self.linksController reloadLinks];
	}
	if (self.highlightsController) {
		[self.highlightsController fetchHighlights];
	}
	[self fetchTags];
}

@end
