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
#import "MBBookmarkLinksController.h"

static NSString* const kHighlightsCountPrefKey = @"HighlightsCount";

@interface MBBookmarksController()
@property (strong, nonatomic) NSButton* linksButton;
@property (strong, nonatomic) MBBookmarkLinksController* linksController;
@property (assign, nonatomic, readwrite) BOOL showingLinks;
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

	[self setupNotifications];
	[self setupWebView];
	[self setupHighlightsButton];
	[self hideCurrentTag];
	[self setupLinksButton];

	[self fetchHighlights];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectTagNotification:) name:kSelectTagNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshBookmarksNotification:) name:kRefreshBookmarksNotification object:nil];
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

- (void) hideCurrentTag
{
	self.currentTagField.stringValue = @"";
	self.currentTagField.hidden = YES;
	self.currentTagCloseButton.hidden = YES;
}

- (void) setupLinksButton
{
	self.linksButton = [NSButton buttonWithTitle:@"Links" target:self action:@selector(toggleLinks:)];
	self.linksButton.bezelStyle = self.tagsButton.bezelStyle;
	self.linksButton.controlSize = self.tagsButton.controlSize;
	self.linksButton.font = self.tagsButton.font;
	[self.linksButton setButtonType:NSButtonTypePushOnPushOff];
	self.linksButton.alternateTitle = @"Links";
	// Keep the tags button's subtle bezel instead of the default blue toggle fill.
	[(NSButtonCell *)self.linksButton.cell setShowsStateBy:NSContentsCellMask];
	self.linksButton.translatesAutoresizingMaskIntoConstraints = NO;
	[self.linksButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
	NSView* bar = self.tagsButton.superview;
	[bar addSubview:self.linksButton];
	for (NSLayoutConstraint* constraint in [bar.constraints copy]) {
		if (constraint.firstItem == self.tagsButton && constraint.firstAttribute == NSLayoutAttributeLeading && constraint.secondItem == self.currentTagField) {
			constraint.active = NO;
		}
	}
	[NSLayoutConstraint activateConstraints:@[
		[self.linksButton.trailingAnchor constraintEqualToAnchor:self.tagsButton.leadingAnchor constant:-8],
		[self.linksButton.leadingAnchor constraintEqualToAnchor:self.currentTagField.trailingAnchor constant:8],
		[self.linksButton.centerYAnchor constraintEqualToAnchor:self.tagsButton.centerYAnchor],
		[self.linksButton.heightAnchor constraintEqualToAnchor:self.tagsButton.heightAnchor]
	]];
}

- (void) toggleLinks:(id)sender
{
	[self setLinksVisible:!self.showingLinks];
}

- (void) setLinksVisible:(BOOL)visible
{
	if (visible && self.linksController == nil) {
		self.linksController = [[MBBookmarkLinksController alloc] init];
		[self addChildViewController:self.linksController];
		NSView* links_view = self.linksController.view;
		links_view.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addSubview:links_view];
		[NSLayoutConstraint activateConstraints:@[
			[links_view.topAnchor constraintEqualToAnchor:self.webView.topAnchor],
			[links_view.bottomAnchor constraintEqualToAnchor:self.webView.bottomAnchor],
			[links_view.leadingAnchor constraintEqualToAnchor:self.webView.leadingAnchor],
			[links_view.trailingAnchor constraintEqualToAnchor:self.webView.trailingAnchor]
		]];
	}
	self.showingLinks = visible;
	self.linksButton.state = visible ? NSControlStateValueOn : NSControlStateValueOff;
	self.linksButton.font = visible ? [NSFont systemFontOfSize:self.tagsButton.font.pointSize weight:NSFontWeightSemibold] : self.tagsButton.font;
	self.webView.hidden = visible;
	self.linksController.view.hidden = !visible;
	self.currentTagField.hidden = visible || self.currentTagField.stringValue.length == 0;
	self.currentTagCloseButton.hidden = self.currentTagField.hidden;
	if (visible) {
		self.selectedPostID = nil;
		[self.linksController reloadLinks];
		[self.view.window makeFirstResponder:self.linksController.view];
	}
	else {
		[self.view.window makeFirstResponder:self.webView];
	}
}

- (void) reloadLinks
{
	[self.linksController reloadLinks];
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
					[item setKeyEquivalent:@"T"];
					[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];

					item = [menu addItemWithTitle:@"New Bookmark" action:@selector(newBookmark:) keyEquivalent:@"b"];
					[item setTarget:[NSApp delegate]];
					[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];

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
	[self setLinksVisible:NO];
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

- (void) hideHighlightsBar
{
	// Links remains available even when there are no tags or highlights.
	self.highlightsTopConstraint.constant = -1;
	self.tagsButton.hidden = YES;
}

- (void) selectTagWithName:(NSString *)tagName
{
	[self setLinksVisible:NO];
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/bookmarks?tag=%@", [tagName rf_urlEncoded]];

	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	self.currentTagField.stringValue = tagName;
	self.currentTagField.hidden = NO;
	self.currentTagCloseButton.hidden = NO;
}

- (void) selectTagNotification:(NSNotification *)notification
{
	NSString* t = [notification.userInfo objectForKey:kSelectTagNameKey];
	[self selectTagWithName:t];
}

- (void) refreshBookmarksNotification:(NSNotification *)notification
{
	[self setupWebView];
	if (self.showingLinks) {
		[self reloadLinks];
	}
}

@end
