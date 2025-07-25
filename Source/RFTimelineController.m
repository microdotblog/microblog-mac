//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

#import "MBSimpleTimelineController.h"
#import "RFMenuCell.h"
#import "RFSeparatorCell.h"
#import "RFPostController.h"
#import "RFPostWindowController.h"
#import "RFAllPostsController.h"
#import "RFAllUploadsController.h"
#import "RFRepliesController.h"
#import "RFBookshelvesController.h"
#import "RFConversationController.h"
#import "RFFriendsController.h"
#import "RFTopicController.h"
#import "RFDiscoverController.h"
#import "RFUserController.h"
#import "MBHighlightsController.h"
#import "MBBookmarksController.h"
#import "RFRoundedImageView.h"
#import "SAMKeychain.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "RFAccount.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "RFPost.h"
#import "RFStack.h"
#import "RFBookshelf.h"
#import "NSObject+SharedTimeline.h"
#import "MBBooksWindowController.h"
#import "MBNotesController.h"
#import "NSImage+Extras.h"
#import "RFGoToUserController.h"
#import "NSAppearance+Extras.h"
#import <QuartzCore/QuartzCore.h>

static NSInteger const kSelectionTimeline = 0;
static NSInteger const kSelectionMentions = 1;
static NSInteger const kSelectionFavorites = 2;
static NSInteger const kSelectionDiscover = 3;
static NSInteger const kSelectionDivider1 = 4;
static NSInteger const kSelectionPosts = 5;
static NSInteger const kSelectionPages = 6;
static NSInteger const kSelectionUploads = 7;
static NSInteger const kSelectionDivider2 = 8;
static NSInteger const kSelectionReplies = 9;
static NSInteger const kSelectionBookshelves = 10;
static NSInteger const kSelectionNotes = 11;

@implementation RFTimelineController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Timeline"];
	if (self) {
		self.navigationStack = [[RFStack alloc] init];
		self.checkSeconds = @5;
		self.booksWindowControllers = [NSMutableArray array];
		self.cachedUsernames = [NSMutableSet set];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupBackground];
	[self setupSidebar];
	[self setupToolbar];
	[self setupFullScreen];
	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
	[self setupUser];
	[self setupNotifications];
	[self setupTimer];
}

- (void) setupBackground
{
	if ([NSAppearance rf_isDarkMode]) {
		self.window.backgroundColor = [NSColor windowBackgroundColor];
	}
	else {
		self.window.backgroundColor = [NSColor whiteColor];
	}
}

- (void) setupToolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"TimelineToolbar"];

    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setDelegate:self];
    
    [self.window setToolbar:toolbar];
	
	[self hidePublishingStatus:NO];
}

- (void) setupFullScreen
{
	self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"MenuCell" bundle:nil] forIdentifier:@"MenuCell"];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
    self.tableView.refusesFirstResponder = YES;
    self.tableView.enclosingScrollView.automaticallyAdjustsContentInsets = NO;
    self.tableView.enclosingScrollView.contentInsets = NSEdgeInsetsMake (5, 0, 0, 0);
}

- (void) setupSplitView
{
	if (NO) {
		self.sidebarController = [[NSViewController alloc] init];
		NSSplitViewItem* sidebar_item = [NSSplitViewItem sidebarWithViewController:self.sidebarController];
		
		self.contentController = [[NSViewController alloc] init];
		NSSplitViewItem* content_item = [NSSplitViewItem contentListWithViewController:self.contentController];
		
		self.splitController = [[NSSplitViewController alloc] init];
		[self.splitController addSplitViewItem:sidebar_item];
		[self.splitController addSplitViewItem:content_item];
		
		self.window.contentViewController = self.splitController;
	}
	else {
		[self.splitView setAutosaveName:@"TimelineSplitView"];
		self.splitView.delegate = self;
		[self.splitView setHoldingPriority:NSLayoutPriorityRequired forSubviewAtIndex:0];
	}
}

- (void) setupWebView
{
	self.messageTopConstraint.constant = -35;
	
//	[self setupWebDelegates:self.webView];
//	[self.webView setDrawsBackground:![NSAppearance rf_isDarkMode]];
	[self showTimeline:nil];
}

- (void) setupWebDelegates:(WebView *)webView
{
	webView.frameLoadDelegate = self;
	webView.policyDelegate = self;
	webView.resourceLoadDelegate = self;
	webView.UIDelegate = self;
}

- (void) setupUser
{
	self.selectedAccount = [RFSettings defaultAccount];

	NSString* full_name = [RFSettings stringForKey:kAccountFullName];
	NSString* username = [RFSettings stringForKey:kAccountUsername];
	NSString* gravatar_url = [RFSettings stringForKey:kAccountGravatarURL];
	
	self.fullNameField.stringValue = full_name;
	self.usernameField.stringValue = [NSString stringWithFormat:@"@%@", username];
	[self.profileImageView loadFromURL:gravatar_url];

	self.fullNameField.nextResponder = self.profileBox;
	self.usernameField.nextResponder = self.profileBox;
	
	if ([NSAppearance rf_isDarkMode]) {
		self.switchAccountView.image = [NSImage imageNamed:@"down_arrow_darkmode"];
	}
	self.switchAccountView.hidden = ([RFSettings accounts].count <= 1);
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidScroll:) name:NSScrollViewWillStartLiveScrollNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasFavoritedNotification:) name:kPostWasFavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasUnfavoritedNotification:) name:kPostWasUnfavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagsDidUpdateNotification:) name:kTagsDidUpdateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showConversationNotification:) name:kShowConversationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sharePostNotification:) name:kSharePostNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(popNavigationNotification:) name:kPopNavigationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showUserFollowingNotification:) name:kShowUserFollowingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showUserProfileNotification:) name:kShowUserProfileNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showDiscoverTopicNotification:) name:kShowDiscoverTopicNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showHighlightsNotification:) name:kShowHighlightsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTimelineNotification:) name:kRefreshTimelineNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkTimelineNotification:) name:kCheckTimelineNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchAccountNotification:) name:kSwitchAccountNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountsNotification:) name:kRefreshAccountsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeAppearanceDidChangeNotification:) name:kDarkModeAppearanceDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openBookshelfNotification:) name:kOpenBookshelfNotification object:nil];

//	[NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
}

- (void) setupTimer
{
	[self.checkTimer invalidate];
	self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkSeconds.floatValue target:self selector:@selector(checkPostsFromTimer:) userInfo:nil repeats:NO];
	self.checkSeconds = @120; // in case it fails, bump to higher default
}

- (void) setupSidebar
{
	self.sidebarItems = [NSMutableArray array];
	
	[self.sidebarItems addObject:@(kSelectionTimeline)];
	[self.sidebarItems addObject:@(kSelectionMentions)];
	[self.sidebarItems addObject:@(kSelectionFavorites)];
	[self.sidebarItems addObject:@(kSelectionDiscover)];
	[self.sidebarItems addObject:@(kSelectionDivider1)];

	if ([RFSettings hasSnippetsBlog] && ![RFSettings prefersExternalBlog]) {
		[self.sidebarItems addObject:@(kSelectionPosts)];
		[self.sidebarItems addObject:@(kSelectionPages)];
		[self.sidebarItems addObject:@(kSelectionUploads)];
		[self.sidebarItems addObject:@(kSelectionDivider2)];
	}
	
	[self.sidebarItems addObject:@(kSelectionReplies)];
	[self.sidebarItems addObject:@(kSelectionBookshelves)];
	[self.sidebarItems addObject:@(kSelectionNotes)];
}

#pragma mark -

- (void) keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@"\r"]) {
		if ([self.selectedPostID length] > 0) {
			[self showConversationWithPostID:self.selectedPostID];
		}
	}
	else {
		[super keyDown:event];
	}
}

- (void) moveUp:(id)sender
{
	NSString* js;
	
	NSString* last_selected_id = nil;
	if ([self.selectedPostID length] > 0) {
		last_selected_id = self.selectedPostID;
		
		// select previous
		js = [NSString stringWithFormat:@"var div = document.getElementById('post_%@');\
			var next_div = div.previousElementSibling;\
			if (next_div && next_div.classList.contains('post')) {\
				next_div.classList.add('is_selected');\
			};", self.selectedPostID];
	}
	else {
		// select first
		js = @"var div = document.querySelector('.post');\
			div.classList.add('is_selected');";
	}
	
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
	[self updateSelectionFromMove];
	
	// deselect last if changed
	if (last_selected_id && ![last_selected_id isEqualToString:self.selectedPostID]) {
		[self setSelected:NO withPostID:last_selected_id];
	}
}

- (void) moveDown:(id)sender
{
	NSString* js;
	
	NSString* last_selected_id = nil;
	if ([self.selectedPostID length] > 0) {
		last_selected_id = self.selectedPostID;
				
		// select next
		js = [NSString stringWithFormat:@"var div = document.getElementById('post_%@');\
   var next_div = div.nextElementSibling;\
   if (next_div && next_div.classList.contains('post')) {\
	next_div.classList.add('is_selected');\
   };", self.selectedPostID];
	}
	else {
		// select first
		js = @"var div = document.querySelector('.post');\
  div.classList.add('is_selected');";
	}
	
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
	[self updateSelectionFromMove];
	
	// deselect last if changed
	if (last_selected_id && ![last_selected_id isEqualToString:self.selectedPostID]) {
		[self setSelected:NO withPostID:last_selected_id];
	}
}

- (void) windowDidBecomeKey:(NSNotification *)notification
{
	NSIndexSet* indexes = [self.tableView selectedRowIndexes];
	[self.tableView reloadData];
	[self.tableView selectRowIndexes:indexes byExtendingSelection:NO];
	if (self.statusBubble.alphaValue != 0.0) {
		// delay changing alpha to avoid clicks right away
		RFDispatchSeconds(1.0, ^{
			self.statusBubble.alphaValue = 1.0;
		});
	}
	
	[self applyForegroundJS:[self currentWebView]];
}

- (void) windowDidResignKey:(NSNotification *)notification
{
	NSIndexSet* indexes = [self.tableView selectedRowIndexes];
	[self.tableView reloadData];
	[self.tableView selectRowIndexes:indexes byExtendingSelection:NO];
	if (self.statusBubble.alphaValue != 0.0) {
		self.statusBubble.alphaValue = 0.5;
	}
	
	[self applyBackgroundJS:[self currentWebView]];
}

- (void) timelineDidScroll:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSView class]]) {
		NSView* view = (NSView *)notification.object;
		if ([view isDescendantOf:[self currentWebView]]) {
		}
	}
}

- (void) postWasFavoritedNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kPostNotificationPostIDKey];
	NSString* js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_favorite');", post_id];
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (void) postWasUnfavoritedNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kPostNotificationPostIDKey];
	NSString* js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_favorite');", post_id];
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (void) tagsDidUpdateNotification:(NSNotification *)notification
{
	id bookmark_id = [notification.userInfo objectForKey:kTagsDidUpdateIDKey];
	NSString* new_tags = [notification.userInfo objectForKey:kTagsDidUpdateTagsKey];
	
	NSString* js = [NSString stringWithFormat:@"document.getElementById('tags_%@').textContent = \"Tags: %@\";", bookmark_id, new_tags];
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (void) showConversationNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kPostNotificationPostIDKey];
	[self showConversationWithPostID:post_id];
}

- (void) sharePostNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kSharePostIDKey];
	[self showShareWithPostID:post_id];
}

- (void) showUserFollowingNotification:(NSNotification *)notification
{
	NSString* username = [notification.userInfo objectForKey:kShowUserFollowingUsernameKey];

	RFFriendsController* controller = [[RFFriendsController alloc] initWithUsername:username];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) showUserProfileNotification:(NSNotification *)notification
{
	NSString* username = [notification.userInfo objectForKey:kShowUserProfileUsernameKey];
	[self showProfileWithUsername:username];
}

- (void) showDiscoverTopicNotification:(NSNotification *)notification
{
	NSString* topic = [notification.userInfo objectForKey:kShowDiscoverTopicNameKey];
	[self showTopicsWithSearch:topic];
}

- (void) showHighlightsNotification:(NSNotification *)notification
{
	[self showHighlights];
}

- (void) refreshTimelineNotification:(NSNotification *)notification
{
	[self refreshTimeline:nil];
}

- (void) checkTimelineNotification:(NSNotification *)notification
{
	self.checkSeconds = @1;
	[self setupTimer];
}

- (void) switchAccountNotification:(NSNotification *)notification
{
	NSString* username = [notification.userInfo objectForKey:kSwitchAccountUsernameKey];
	[[NSUserDefaults standardUserDefaults] setObject:username forKey:kCurrentUsername];
	
	[self setupUser];
	[self showTimeline:nil];
}

- (void) refreshAccountsNotification:(NSNotification *)notification
{
	// see if current account was removed
	BOOL found = NO;
	NSArray* accounts = [RFSettings accounts];
	for (RFAccount* a in accounts) {
		if (self.selectedAccount && [a.username isEqualToString:self.selectedAccount.username]) {
			found = YES;
		}
	}
	
	if (!found) {
		[self setupUser];
		[self showTimeline:nil];
	}

	// add the arrow if we now have multiple accounts
	self.switchAccountView.hidden = ([RFSettings accounts].count <= 1);
}

- (void) darkModeAppearanceDidChangeNotification:(NSNotification *)notification
{
	[self setupUser];
	[self.webView setDrawsBackground:![NSAppearance rf_isDarkMode]];
	[self showTimeline:nil];
}

- (void) popNavigationNotification:(NSNotification *)notification
{
	[self popViewController];
}

- (void) openBookshelfNotification:(NSNotification *)notification
{
	RFBookshelf* bookshelf = [notification.userInfo objectForKey:kOpenBookshelfKey];
	MBBooksWindowController* found_controller = nil;
	
	for (MBBooksWindowController* controller in self.booksWindowControllers) {
		if ([controller.bookshelf.bookshelfID isEqualToNumber:bookshelf.bookshelfID]) {
			found_controller = controller;
			break;
		}
	}
	
	if (found_controller) {
		[found_controller showWindow:nil];
		[found_controller fetchBooks];
	}
	else {
		MBBooksWindowController* books_controller = [[MBBooksWindowController alloc] initWithBookshelf:bookshelf];
		[books_controller showWindow:nil];

		[self.booksWindowControllers addObject:books_controller];
	}
}

#pragma mark -

- (IBAction) performClose:(id)sender
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		self.postController.view.animator.alphaValue = 0.0;
	} completionHandler:^{
		[self.postController finishClose];
		[self.postController.view removeFromSuperview];
		self.postController = nil;
	}];
}

- (IBAction) showTimeline:(id)sender
{
	self.selectedTimeline = kSelectionTimeline;

	[self closeOverlays];

	NSString* username = [RFSettings stringForKey:kAccountUsername];
	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];
	
	CGFloat scroller_width = 0;
	if (NSScroller.preferredScrollerStyle == NSScrollerStyleLegacy) {
		scroller_width = [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy];
	}
	CGFloat pane_width = self.webView.bounds.size.width;
	int timezone_minutes = 0;

	NSInteger text_size = [[NSUserDefaults standardUserDefaults] integerForKey:kTextSizePrefKey];
	if (text_size == 0) {
		text_size = kTextSizeMedium;
	}
	
	long darkmode = [NSAppearance rf_isDarkMode] ? 1 : 0;

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1&fontsize=%ld&darkmode=%ld&fontsystem=1&show_actions=1&show_tags=1", token, pane_width - scroller_width, timezone_minutes, (long)text_size, darkmode];

	MBSimpleTimelineController* controller = [[MBSimpleTimelineController alloc] initWithURL:url];
	[controller view];
	[self setupWebDelegates:controller.webView];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionTimeline];
	[self startLoadingSidebarRow:kSelectionTimeline];
}

- (IBAction) showMentions:(id)sender
{
	self.selectedTimeline = kSelectionMentions;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/mentions"];
	
	MBSimpleTimelineController* controller = [[MBSimpleTimelineController alloc] initWithURL:url];
	[controller view];
	[self setupWebDelegates:controller.webView];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionMentions];
	[self startLoadingSidebarRow:kSelectionMentions];
}

- (IBAction) showFavorites:(id)sender
{
	self.selectedTimeline = kSelectionFavorites;

	[self closeOverlays];

	MBBookmarksController* controller = [[MBBookmarksController alloc] init];
	[controller view];
	[self setupWebDelegates:controller.webView];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionFavorites];
	[self startLoadingSidebarRow:kSelectionFavorites];
}

- (IBAction) showDiscover:(id)sender
{
	self.selectedTimeline = kSelectionDiscover;

	[self closeOverlays];

	RFDiscoverController* controller = [[RFDiscoverController alloc] init];
	[controller view];
	[self setupWebDelegates:controller.webView];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionDiscover];
	[self startLoadingSidebarRow:kSelectionDiscover];
}

- (IBAction) showPosts:(id)sender
{
	self.selectedTimeline = kSelectionPosts;

	[self closeOverlays];

	RFAllPostsController* controller = [[RFAllPostsController alloc] initShowingPages:NO];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionPosts];
	[self startLoadingSidebarRow:kSelectionPosts];
}

- (IBAction) showPages:(id)sender
{
	self.selectedTimeline = kSelectionPages;

	[self closeOverlays];

	RFAllPostsController* controller = [[RFAllPostsController alloc] initShowingPages:YES];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionPages];
	[self startLoadingSidebarRow:kSelectionPages];
}

- (IBAction) showUploads:(id)sender
{
	self.selectedTimeline = kSelectionUploads;

	[self closeOverlays];

	RFAllUploadsController* controller = [[RFAllUploadsController alloc] init];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionUploads];
	[self startLoadingSidebarRow:kSelectionUploads];
}

- (IBAction) showReplies:(id)sender
{
	self.selectedTimeline = kSelectionReplies;

	[self closeOverlays];

	RFRepliesController* controller = [[RFRepliesController alloc] init];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionReplies];
	[self startLoadingSidebarRow:kSelectionReplies];
}

- (IBAction) showBookshelves:(id)sender
{
	self.selectedTimeline = kSelectionBookshelves;

	[self closeOverlays];

	RFBookshelvesController* controller = [[RFBookshelvesController alloc] init];
	[self showRootController:controller];

	[self selectSidebarRow:kSelectionBookshelves];
	[self startLoadingSidebarRow:kSelectionBookshelves];
}

- (IBAction) showNotes:(id)sender
{
	self.selectedTimeline = kSelectionNotes;

	[self closeOverlays];

	if (self.notesController == nil) {
		self.notesController = [[MBNotesController alloc] init];
	}
	else {
		[self.notesController deselectAll];
		[self.notesController fetchNotes];
	}
	
	[self showRootController:self.notesController];

	[self selectSidebarRow:kSelectionNotes];
	[self startLoadingSidebarRow:kSelectionNotes];
}

- (IBAction) refreshTimeline:(id)sender
{
	[self.messageSpinner startAnimation:nil];
	
	if (self.selectedTimeline == kSelectionTimeline) {
		[self showTimeline:nil];
	}
	else if (self.selectedTimeline == kSelectionMentions) {
		[self showMentions:nil];
	}
	else if (self.selectedTimeline == kSelectionFavorites) {
		[self showFavorites:nil];
	}
	else if (self.selectedTimeline == kSelectionDiscover) {
		[self showDiscover:nil];
	}
	else if (self.selectedTimeline == kSelectionPosts) {
		if ([self.rootController isKindOfClass:[RFAllPostsController class]]) {
			[(RFAllPostsController *)self.rootController fetchPosts];
		}
	}
	else if (self.selectedTimeline == kSelectionPages) {
		if ([self.rootController isKindOfClass:[RFAllPostsController class]]) {
			[(RFAllPostsController *)self.rootController fetchPosts];
		}
	}
	else if (self.selectedTimeline == kSelectionUploads) {
		if ([self.rootController isKindOfClass:[RFAllUploadsController class]]) {
			[(RFAllUploadsController *)self.rootController fetchUploads];
		}
	}
	else if (self.selectedTimeline == kSelectionReplies) {
		if ([self.rootController isKindOfClass:[RFRepliesController class]]) {
			[(RFRepliesController *)self.rootController fetchReplies];
		}
	}
	else if (self.selectedTimeline == kSelectionNotes) {
		if ([self.rootController isKindOfClass:[MBNotesController class]]) {
			[(MBNotesController *)self.rootController fetchNotes];
		}
	}

	RFDispatchSeconds (1.5, ^{
		[self hideMessageField];
	});
}

- (IBAction) goToUser:(id)sender
{
	self.goToUserController = [[RFGoToUserController alloc] init];
	[self.window beginSheet:self.goToUserController.window completionHandler:^(NSModalResponse returnCode) {
        self.goToUserController = nil;
	}];
}

- (IBAction) goToProfile:(id)sender
{
	RFAccount* a = [RFSettings defaultAccount];
	if (a) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kShowUserProfileNotification object:self userInfo:@{ kShowUserProfileUsernameKey: a.username }];
	}
}

- (IBAction) toggleBookmarkSummaries:(id)sender
{
	BOOL was_showing = [RFSettings boolForKey:kIsShowingBookmarkSummaries];
	[RFSettings setBool:!was_showing forKey:kIsShowingBookmarkSummaries];
	
	NSDictionary* params = @{
		@"summaries": @(!was_showing)
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/bookmarks/settings"];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
	}];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshBookmarksNotification object:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(performFindPanelAction:)) {
		if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionDiscover)) {
			return YES;
		}
		else if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionPosts)) {
			return YES;
		}
		else if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionPages)) {
			return YES;
		}
		else if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionUploads)) {
			return YES;
		}
		else if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionReplies)) {
			return YES;
		}
		else if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionNotes)) {
			return YES;
		}
		else {
			return NO;
		}
	}
	else if (item.action == @selector(showPosts:)) {
		if (![RFSettings isUsingMicroblog]) {
			return NO;
		}
	}
	else if (item.action == @selector(showPages:)) {
		if (![RFSettings isUsingMicroblog]) {
			return NO;
		}
	}
	else if (item.action == @selector(showUploads:)) {
		if (![RFSettings isUsingMicroblog]) {
			return NO;
		}
	}
	else if (item.action == @selector(reply:)) {
		if (self.selectedPostID.length == 0) {
			return NO;
		}
	}
	else if (item.action == @selector(goToProfile:)) {
		RFAccount* a = [RFSettings defaultAccount];
		if (a) {
			NSString* s = [NSString stringWithFormat:@"Go to @%@", a.username];
			[item setTitle:s];
		}
	}
	else if (item.action == @selector(toggleBookmarkSummaries:)) {
		if ([RFSettings boolForKey:kIsShowingBookmarkSummaries]) {
			[item setState:NSControlStateValueOn];
		}
		else {
			[item setState:NSControlStateValueOff];
		}

		if (self.selectedTimeline != kSelectionFavorites) {
			return NO;
		}
	}
	
	return YES;
}

- (void) performFindPanelAction:(id)sender
{
	if (self.selectedTimeline == kSelectionDiscover) {
		if ([self.rootController isKindOfClass:[RFDiscoverController class]]) {
			[(RFDiscoverController *)self.rootController showSearch:nil];
		}
	}
	else if (self.selectedTimeline == kSelectionPosts) {
		if ([self.rootController isKindOfClass:[RFAllPostsController class]]) {
			[(RFAllPostsController *)self.rootController focusSearch];
		}
	}
	else if (self.selectedTimeline == kSelectionPages) {
		if ([self.rootController isKindOfClass:[RFAllPostsController class]]) {
			[(RFAllPostsController *)self.rootController focusSearch];
		}
	}
	else if (self.selectedTimeline == kSelectionUploads) {
		if ([self.rootController isKindOfClass:[RFAllUploadsController class]]) {
			[(RFAllUploadsController *)self.rootController focusSearch];
		}
	}
	else if (self.selectedTimeline == kSelectionReplies) {
		if ([self.rootController isKindOfClass:[RFRepliesController class]]) {
			[(RFRepliesController *)self.rootController focusSearch];
		}
	}
	else if (self.selectedTimeline == kSelectionNotes) {
		if ([self.rootController isKindOfClass:[MBNotesController class]]) {
			[(MBNotesController *)self.rootController focusSearch];
		}
	}
}

- (IBAction) reply:(id)sender
{
	if (self.selectedPostID.length > 0) {
		NSString* url = [NSString stringWithFormat:@"microblog://reply/%@", self.selectedPostID];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
	}
}

#pragma mark -

- (void) checkPostsFromTimer:(NSTimer *)timer
{
	// only check for new posts if timeline selected
	NSMutableDictionary* args = [NSMutableDictionary dictionary];
	if (self.selectedTimeline == kSelectionTimeline) {
		NSString* top_post_id = [self topPostID];
		if (top_post_id.length > 0) {
			[args setObject:top_post_id forKey:@"since_id"];
		}
	}
	
	// always call to get publishing status, even if no new posts
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/check"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSNumber* count = [response.parsedResponse objectForKey:@"count"];
			NSNumber* check_seconds = [response.parsedResponse objectForKey:@"check_seconds"];
			NSNumber* is_publishing = [response.parsedResponse objectForKey:@"is_publishing"];
			if (is_publishing && [is_publishing boolValue]) {
				RFDispatchMainAsync (^{
					[self showPublishingStatus];
				});
			}
			else if (count && count.integerValue > 0) {
				NSString* msg;
				if (count.integerValue == 1) {
					msg = @"1 new post";
				}
				else if (count.integerValue >= 40) {
					msg = @"40+ new posts";
				}
				else {
					msg = [NSString stringWithFormat:@"%@ new posts", count];
				}

				RFDispatchMainAsync (^{
					[self showMessageField:msg];
					[self hidePublishingStatus:YES];
				});
			}
			else {
				RFDispatchMainAsync (^{
					[self hideMessageField];
					[self hidePublishingStatus:YES];
				});
			}

			if (check_seconds && check_seconds.integerValue > 2) { // sanity check value
				self.checkSeconds = check_seconds;
			}

			RFDispatchMainAsync (^{
				[self setupTimer];
			});
		}
	}];

	[self setupTimer];
}

- (void) closeOverlays
{
	self.webView.hidden = YES;
	[self popToRootViewController];
	
	self.messageTopConstraint.animator.constant = -35;
	[self.messageSpinner stopAnimation:nil];

	if (self.rootController) {
		[self.rootController.view removeFromSuperview];
		self.rootController = nil;
	}
	
	self.overlayLeftConstraint = nil;
	self.overlayRightConstraint = nil;

	[self performClose:nil];
}

- (WebView *) currentWebView
{
	NSViewController* controller = [self.navigationStack peek];
	if ([controller isKindOfClass:[RFConversationController class]]) {
		RFConversationController* conversation_controller = (RFConversationController *)controller;
		return conversation_controller.webView;
	}
	else if ([controller isKindOfClass:[RFUserController class]]) {
		RFUserController* user_controller = (RFUserController *)controller;
		return user_controller.webView;
	}
	else if ([controller isKindOfClass:[RFFriendsController class]]) {
		RFFriendsController* friends_controller = (RFFriendsController *)controller;
		return friends_controller.webView;
	}
	else if ([controller isKindOfClass:[RFTopicController class]]) {
		RFTopicController* topic_controller = (RFTopicController *)controller;
		return topic_controller.webView;
	}
	else if ([controller isKindOfClass:[MBSimpleTimelineController class]]) {
		MBSimpleTimelineController* simple_controller = (MBSimpleTimelineController *)controller;
		return simple_controller.webView;
	}
	else if ([controller isKindOfClass:[RFDiscoverController class]]) {
		RFDiscoverController* discover_controller = (RFDiscoverController *)controller;
		return discover_controller.webView;
	}
	else if ([controller isKindOfClass:[MBBookmarksController class]]) {
		MBBookmarksController* bookmarks_controller = (MBBookmarksController *)controller;
		return bookmarks_controller.webView;
	}
	else if ([self.rootController isKindOfClass:[MBSimpleTimelineController class]]) {
		MBSimpleTimelineController* simple_controller = (MBSimpleTimelineController *)self.rootController;
		return simple_controller.webView;
	}
	else if ([self.rootController isKindOfClass:[RFDiscoverController class]]) {
		RFDiscoverController* discover_controller = (RFDiscoverController *)self.rootController;
		return discover_controller.webView;
	}
	else if ([self.rootController isKindOfClass:[MBBookmarksController class]]) {
		MBBookmarksController* bookmarks_controller = (MBBookmarksController *)self.rootController;
		return bookmarks_controller.webView;
	}
	else {
		return self.webView;
	}
}

- (NSView *) currentContainerView
{
	if ([self.navigationStack count] > 0) {
		NSViewController* controller = [self.navigationStack peek];
		return controller.view;
	}
	else if ([self.rootController isKindOfClass:[RFDiscoverController class]]) {
		return ((RFDiscoverController *)self.rootController).view;
	}
	else if ([self.rootController isKindOfClass:[MBBookmarksController class]]) {
		return ((MBBookmarksController *)self.rootController).view;
	}
	else if ([self.rootController isKindOfClass:[MBSimpleTimelineController class]]) {
		return ((MBSimpleTimelineController *)self.rootController).view;
	}
	else {
		return self.webView;
	}
}

- (void) pushViewController:(NSViewController *)controller
{
	if ([self.navigationStack count] == 0) {
		if (self.overlayLeftConstraint) {
			self.navigationLeftConstraint = self.overlayLeftConstraint;
			self.navigationRightConstraint = self.overlayRightConstraint;
		}
		else {
//			self.navigationLeftConstraint = self.timelineLeftConstraint;
//			self.navigationRightConstraint = self.timelineRightConstraint;
		}
		self.navigationLeftConstraint.constant = 0;
		self.navigationRightConstraint.constant = 0;
	}

	// restore fixed constraint
	if (self.navigationRightConstraint) {
		self.navigationRightConstraint.active = YES;
	}
	if (self.navigationPinnedConstraint) {
		self.navigationPinnedConstraint.active = NO;
	}

	WebView* current_webview = [self currentWebView];
	NSView* last_view = [self currentContainerView];
	[self.navigationStack push:controller];
	controller.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.containerView addSubview:controller.view positioned:NSWindowAbove relativeTo:current_webview];

	[self addFixedConstraintsToView:controller.view containerView:last_view];
	[controller.view setNeedsLayout:YES];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		context.duration = 0.3;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
		self.navigationLeftConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
		if (self.overlayLeftConstraint) {
			// constant is reversed here
			self.navigationRightConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
		}
		else {
			self.navigationRightConstraint.animator.constant = [self.navigationStack count] * self.containerView.bounds.size.width;
		}
	} completionHandler:^{
		// after animating, temporary pin to right
		self.navigationRightConstraint.active = NO;
		self.navigationPinnedConstraint.active = YES;
		
		// focus new controller
		[self.window makeFirstResponder:controller];
	}];
}

- (void) popViewController
{
	NSViewController* controller = [self.navigationStack pop];
	if (controller) {
		// restore fixed constraint
		self.navigationRightConstraint.active = YES;
		self.navigationPinnedConstraint.active = NO;

		[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
			context.duration = 0.3;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

			self.navigationLeftConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
			self.navigationRightConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
		} completionHandler:^{
			[controller.view removeFromSuperview];

			// focus old controller
			NSViewController* controller = [self.navigationStack peek];
			if (controller) {
				[self.window makeFirstResponder:controller];
			}
			else {
				[self.window makeFirstResponder:self.rootController];
			}
		}];
	}
}

- (void) popToRootViewController
{
	while ([self.navigationStack peek] != nil) {
		[self popViewController];
	}
}

- (void) addFixedConstraintsToView:(NSView *)addingView containerView:(NSView *)lastView
{
	NSLayoutConstraint* left_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0];
	left_constraint.priority = NSLayoutPriorityDefaultHigh;
	left_constraint.active = YES;

	NSLayoutConstraint* right_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0];
	right_constraint.priority = NSLayoutPriorityDefaultHigh;
	right_constraint.active = NO;
	self.navigationPinnedConstraint = right_constraint;

	NSLayoutConstraint* top_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
	top_constraint.priority = NSLayoutPriorityDefaultHigh;
	top_constraint.active = YES;

	NSLayoutConstraint* bottom_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
	bottom_constraint.priority = NSLayoutPriorityDefaultHigh;
	bottom_constraint.active = YES;

	NSLayoutConstraint* width_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.containerView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.0];
	width_constraint.priority = NSLayoutPriorityDefaultHigh;
	width_constraint.active = YES;

//	NSLayoutConstraint* width_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:self.containerView.bounds.size.width];
//	width_constraint.priority = NSLayoutPriorityDefaultHigh;
//	width_constraint.active = YES;
}

- (void) addResizeConstraintsToOverlay:(NSView *)addingView containerView:(NSView *)lastView
{
	NSLayoutConstraint* left_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0];
	left_constraint.priority = NSLayoutPriorityDefaultHigh;
	left_constraint.active = YES;

	self.overlayLeftConstraint = left_constraint;
	
	NSLayoutConstraint* right_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0];
	right_constraint.priority = NSLayoutPriorityDefaultHigh;
	right_constraint.active = YES;
	
	self.overlayRightConstraint = right_constraint;

	NSLayoutConstraint* top_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
	top_constraint.priority = NSLayoutPriorityDefaultHigh;
	top_constraint.active = YES;

	NSLayoutConstraint* bottom_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
	bottom_constraint.priority = NSLayoutPriorityDefaultHigh;
	bottom_constraint.active = YES;

//	NSLayoutConstraint* width_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:self.containerView.bounds.size.width];
//	width_constraint.priority = NSLayoutPriorityDefaultHigh;
//	width_constraint.active = YES;
}

- (void) showRootController:(NSViewController *)controller
{
	self.rootController = controller;

	NSRect r = self.webView.bounds;
	self.rootController.view.frame = r;
	self.rootController.view.alphaValue = 0.0;
	
	self.rootController.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.containerView addSubview:self.rootController.view positioned:NSWindowAbove relativeTo:self.webView];

	self.rootController.view.animator.alphaValue = 1.0;
	[self addResizeConstraintsToOverlay:self.rootController.view containerView:self.containerView];

	RFDispatchMainAsync(^{
		[self.window makeFirstResponder:controller];
	});
}

- (void) showTopicsWithSearch:(NSString *)term
{
	RFTopicController* controller = [[RFTopicController alloc] initWithTopic:term];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) showHighlights
{
	NSViewController* controller = [[MBHighlightsController alloc] init];
	[controller view];
	
	[self pushViewController:controller];
}

- (void) showConversationWithPostID:(NSString *)postID
{
	// select and remember webview for unselection
	WebView* current_webview = [self currentWebView];
	[self setPressed:YES withPostID:postID];
	
	RFConversationController* controller = [[RFConversationController alloc] initWithPostID:postID];
	[controller view];
	[self setupWebDelegates:controller.webView];
	
	// give the selection a moment to be visible before animating away
	RFDispatchSeconds (0.1, ^{
		[self pushViewController:controller];
	});
	
	// unselect after delay
	NSString* js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_pressed');", postID];
	RFDispatchSeconds (0.5, ^{
		[current_webview stringByEvaluatingJavaScriptFromString:js];
	});
}

- (void) showShareWithPostID:(NSString *)postID
{
	NSString* link = [self linkOfPostID:postID];
	NSURL* url = [NSURL URLWithString:link];
	
	[[NSWorkspace sharedWorkspace] openURL:url];	

//	NSArray* items = @[ [NSURL URLWithString:@"https://manton.org/"] ];
//	NSSharingServicePicker* picker = [[NSSharingServicePicker alloc] initWithItems:items];
//	picker.delegate = self;
//
//	NSRect r = [self rectOfPostID:postID];
//	[picker showRelativeToRect:r ofView:[self currentWebView] preferredEdge:NSRectEdgeMinY];
}

- (void) showProfileWithUsername:(NSString *)username
{
	if (self.selectedTimeline >= kSelectionPosts) {
		[self showTimeline:nil];
	}

	// check username cache first, then check server
	if ([self.cachedUsernames containsObject:username]) {
		// navigate to profile
		[self showProfileWithExistingUsername:username];
	}
	else {
		[self checkUsername:username completion:^(BOOL exists) {
			if (exists) {
				// cache our answer
				[self.cachedUsernames addObject:username];
				
				// navigate to profile
				[self showProfileWithExistingUsername:username];
			}
			else {
				// no username, so visit that path on the web
				NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://micro.blog/%@", username]];
				[[NSWorkspace sharedWorkspace] openURL:url];
			}
		}];
	}
}

- (void) showProfileWithExistingUsername:(NSString *)username
{
	RFUserController* controller = [[RFUserController alloc] initWithUsername:username];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) checkUsername:(NSString *)username completion:(void (^)(BOOL exists))handler
{
	// get the JSON Feed for the user, will be 404 if no username exists
	RFClient* client = [[RFClient alloc] initWithFormat:@"/posts/%@", username];
	[client getWithCompletion:^(UUHttpResponse* response) {
		BOOL found_user = NO;
		if (response.httpError == nil) {
			found_user = YES;
		}
		RFDispatchMain(^{
			handler(found_user);
		});
	}];
}

- (void) updateCachedUsers
{
	NSArray* usernames = [self usernamesInCurrentView];
	[self.cachedUsernames addObjectsFromArray:usernames];
}

- (void) selectSidebarRow:(NSInteger)sidebarRow
{
	for (NSInteger row = 0; row < self.sidebarItems.count; row++) {
		NSInteger sidebar_row = [[self.sidebarItems objectAtIndex:row] integerValue];
		if (sidebar_row == sidebarRow) {
			[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			break;
		}
	}
	
	[self updateToolbarForSidebarSelection];
}

- (void) startLoadingSidebarRow:(NSInteger)sidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStartLoading object:self userInfo:@{
		kTimelineSidebarRowKey: @(sidebarRow)
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

#pragma mark -

- (void) showNotificationWithTitle:(NSString *)title text:(NSString *)text
{
	NSUserNotification* notification = [[NSUserNotification alloc] init];
	notification.title = title;
	notification.informativeText = text;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
	[self showMentions:nil];
}

- (NSArray<NSSharingService *> *)sharingServicePicker:(NSSharingServicePicker *)sharingServicePicker sharingServicesForItems:(NSArray *)items proposedSharingServices:(NSArray<NSSharingService *> *)proposedServices
{
	NSURL* item = [items objectAtIndex:0];
	NSURL* app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:item];
	NSImage* browser_img = [[NSWorkspace sharedWorkspace] iconForFile:app_url.path];

	NSMutableArray* services = [proposedServices mutableCopy];
	NSSharingService* browser_service = [[NSSharingService alloc] initWithTitle:@"Open in Browser" image:browser_img alternateImage:nil handler:^{
		[[NSWorkspace sharedWorkspace] openURL:item];
	}];
	[services insertObject:browser_service atIndex:0];
	
	return services;
}

#pragma mark -

- (NSString *) topPostID
{
	// class: "post post_1234"
	NSString* js = @"$('.post')[0].id.split('_')[1]";
	NSString* post_id = [[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
	return post_id;
}

- (NSString *) findSelectedPostID
{
	// get selection ignoring current selected post ID
	NSString* js = [NSString stringWithFormat:@"var divs = document.querySelectorAll('div.post.is_selected');"
		"if (divs.length > 0) {"
		"	var result = Array.from(divs).find(post => post.id !== 'post_%@');"
		"	if (result == null) {"
		"		'%@';"
		"	}"
		"	else {"
		"		result.id.split('_')[1];"
		"	}"
		"}"
		"else {"
		"	'%@';"
		"}", self.selectedPostID, self.selectedPostID, self.selectedPostID];
	NSString* post_id = [[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
	return post_id;
}

- (void) setSelected:(BOOL)isSelected withPostID:(NSString *)postID
{
	NSString* js;
	if (isSelected) {
		js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_selected');", postID];
	}
	else {
		js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_selected');", postID];
	}
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (void) setPressed:(BOOL)isPressed withPostID:(NSString *)postID
{
	NSString* js;
	if (isPressed) {
		js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_pressed');", postID];
	}
	else {
		js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_pressed');", postID];
	}
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (void) updateSelectionFromMove
{
	self.selectedPostID = [self findSelectedPostID];
	NSString* js = [NSString stringWithFormat:@"document.getElementById('post_%@').scrollIntoView({ behavior: 'smooth', block: 'nearest' });", self.selectedPostID];
	[[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
}

- (NSRect) rectOfPostID:(NSString *)postID
{
	NSString* top_js = [NSString stringWithFormat:@"$('#post_%@').position().top;", postID];
	NSString* height_js = [NSString stringWithFormat:@"$('#post_%@').height();", postID];
	NSString* scroll_js = [NSString stringWithFormat:@"window.pageYOffset;"];

	NSString* top_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:top_js];
	NSString* height_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:height_js];
	NSString* scroll_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:scroll_js];
    
	CGFloat top_f = [self currentWebView].bounds.size.height - [top_s floatValue] - [height_s floatValue];
	top_f += [scroll_s floatValue];
	
	// adjust to full cell width
	CGFloat left_f = 0.0;
	CGFloat width_f = [self currentWebView].bounds.size.width;
	
	return NSMakeRect (left_f, top_f, width_f, [height_s floatValue]);
}

- (NSString *) usernameOfPostID:(NSString *)postID
{
	NSString* username_js = [NSString stringWithFormat:@"$('#post_%@').find('.post_username').text();", postID];
	NSString* username_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:username_js];
	return [username_s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray *) usernamesInCurrentView
{
	NSString* js = @"Array.from(document.querySelectorAll('.post_username'))\
		.map(e => e.textContent.trim())\
		.filter(u => u.length > 0)\
		.join(',');";
	
	NSString* usernames_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:js];
	NSArray* usernames = [usernames_s componentsSeparatedByString:@","];
	return usernames;
}

- (NSString *) linkOfPostID:(NSString *)postID
{
	NSString* username_js = [NSString stringWithFormat:@"$('#post_%@').find('.post_link').text();", postID];
	NSString* username_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:username_js];
	return [username_s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

//- (RFOptionsPopoverType) popoverTypeOfPostID:(NSString *)postID
//{
//	NSString* is_favorite_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_favorite');", postID];
//	NSString* is_deletable_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_deletable');", postID];
//
//	NSString* is_favorite_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:is_favorite_js];
//	NSString* is_deletable_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:is_deletable_js];
//}

- (void) showURL:(NSURL *)url
{
	BOOL found_microblog_url = NO;
	
	NSString* hostname = [url host];
	NSString* path = [url path];
	if ([hostname isEqualToString:@"micro.blog"]) {
		NSMutableArray* pieces = [[path componentsSeparatedByString:@"/"] mutableCopy];
		[pieces removeObjectAtIndex:0];
		if ([path containsString:@"/account/"]) {
			// e.g. /account/logs
			found_microblog_url = NO;
		}
		else if ((pieces.count == 2) && [[pieces firstObject] isEqualToString:@"discover"]) {
			// e.g. /discover/books
			found_microblog_url = YES;
			[self showTopicsWithSearch:[pieces lastObject]];
		}
		else if ([[pieces firstObject] isEqualToString:@"about"]) {
			// e.g. /about/api
			found_microblog_url = NO;
		}
		else if ([[pieces firstObject] isEqualToString:@"books"]) {
			// e.g. /books/12345
			found_microblog_url = NO;
		}
		else if ([[pieces firstObject] isEqualToString:@"bookmarks"]) {
			// e.g. /bookmarks/12345
			found_microblog_url = NO;
		}
		else if ([[pieces firstObject] isEqualToString:@"discover"]) {
			// e.g. /discover
			found_microblog_url = YES;
			[self showDiscover:nil];
		}
		else if (pieces.count == 2) {
			// e.g. /manton/12345
			found_microblog_url = YES;
			[self showConversationWithPostID:[pieces lastObject]];
		}
		else {
			NSString* username = [path stringByReplacingOccurrencesOfString:@"/" withString:@""];
			if (username.length > 0) {
				// e.g. /manton
				found_microblog_url = YES;
				[self showProfileWithUsername:username];
			}
		}
	}
	
	if (!found_microblog_url) {
		if ([url.pathExtension isEqualToString:@"jpg"] || [url.pathExtension isEqualToString:@"png"]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPhotoURLNotification object:self userInfo:@{ kOpenPhotoURLKey: url }];
		}
		else {
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
	}
}

- (void) showPublishingStatus
{
	if (@available(macOS 15.0, *)) {
		if (![self.window.toolbar.itemIdentifiers containsObject:@"StatusBubble"]) {
			[self.window.toolbar insertItemWithItemIdentifier:@"StatusBubble" atIndex:0];
		}
	}
	[self.statusProgressSpinner startAnimation:nil];
	self.statusBubble.animator.alphaValue = 1.0;
}

- (void) hidePublishingStatus:(BOOL)animate
{
	if (@available(macOS 15.0, *)) {
		if ([self.window.toolbar.itemIdentifiers containsObject:@"StatusBubble"]) {
			[self.window.toolbar removeItemWithItemIdentifier:@"StatusBubble"];
		}
	}
	[self.statusProgressSpinner stopAnimation:nil];
	if (animate) {
		self.statusBubble.animator.alphaValue = 0.0;
	}
	else {
		self.statusBubble.alphaValue = 0.0;
	}
}

- (void) showMessageField:(NSString *)message
{
	if (self.selectedTimeline == kSelectionTimeline) {
		self.messageField.stringValue = message;
		self.messageTopConstraint.animator.constant = -1;
	}
}

- (void) hideMessageField
{
	self.messageTopConstraint.animator.constant = -35;
	[self.messageSpinner stopAnimation:nil];
}

- (BOOL) isSelectedFavorites
{
	return (self.selectedTimeline == kSelectionFavorites);
}

- (void) updateToolbarForSidebarSelection
{
	NSToolbar* toolbar = self.window.toolbar;
	BOOL should_show_upload = self.selectedTimeline == kSelectionUploads;
	BOOL upload_exists = NO;
	
	// check if the UploadButton already exists in the toolbar
	for (NSToolbarItem* item in toolbar.items) {
		if ([item.itemIdentifier isEqualToString:@"UploadButton"]) {
			upload_exists = YES;
			break;
		}
	}
	
	if (should_show_upload && !upload_exists) {
		// insert the UploadButton at a desired index
		NSInteger insert_index = toolbar.items.count - 2;
		[toolbar insertItemWithItemIdentifier:@"UploadButton" atIndex:insert_index];
	}
	else if (!should_show_upload && upload_exists) {
		// remove the UploadButton if it's there
		NSInteger index_to_remove = NSNotFound;
		for (NSInteger i = 0; i < toolbar.items.count; i++) {
			NSToolbarItem* item = [toolbar.items objectAtIndex:i];
			if ([item.itemIdentifier isEqualToString:@"UploadButton"]) {
				index_to_remove = i;
				break;
			}
		}
		if (index_to_remove != NSNotFound) {
			[toolbar removeItemAtIndex:index_to_remove];
		}
	}
}

#pragma mark -

- (void) webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame
{
	NSScrollView* scrollview = webView.mainFrame.frameView.documentView.enclosingScrollView;
	[scrollview setVerticalScrollElasticity:NSScrollElasticityAllowed];
	[scrollview setHorizontalScrollElasticity:NSScrollElasticityNone];
		
	[self setupCSS:webView];	
	[self stopLoadingSidebarRow];
	[self updateCachedUsers];
}

- (void) webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if ([[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue] == WebNavigationTypeLinkClicked) {
		[self showURL:request.URL];
		[listener ignore];
	}
	else if ([request.URL.scheme isEqualToString:@"microblog"]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kOpenMicroblogURLNotification object:self userInfo:@{ kOpenMicroblogURLKey: request.URL }];
		[listener ignore];
	}
	else {
		[listener use];
	}
}

- (void) webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource
{
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse* url_response = (NSHTTPURLResponse *)response;
		NSInteger status_code = [url_response statusCode];
		if ((status_code == 500) && [[[url_response URL] host] isEqualToString:@"micro.blog"]) {
			[[sender mainFrame] loadHTMLString:@"" baseURL:nil];
		
			NSString* msg = [NSString stringWithFormat:@"If the error continues, try restarting Micro.blog or choosing File → Sign Out. (HTTP code: %ld)", (long)status_code];
		
			NSAlert* alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"Error loading Micro.blog timeline"];
			[alert setInformativeText:msg];
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			}];
		}
	}
}

- (void) webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
	NSHTTPURLResponse* url_response = (NSHTTPURLResponse *)dataSource.response;
	NSInteger status_code = [url_response statusCode];
	if (status_code == 500) {
	}
}

- (void) webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
	NSLog (@"WebView did fail: %@", error);
}

- (NSArray *) webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray* new_items = [NSMutableArray array];

	for (NSMenuItem* item in defaultMenuItems) {
		switch (item.tag) {
			case 2000: // Open Link
			case WebMenuItemTagOpenLinkInNewWindow:
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagOpenImageInNewWindow:
			case WebMenuItemTagDownloadImageToDisk:
				break;
			
			default:
				[new_items addObject:item];
				break;
		}
	}

	return new_items;
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return [self.sidebarItems count];
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	NSInteger sidebar_row = [[self.sidebarItems objectAtIndex:row] integerValue];
	
    if ((sidebar_row == kSelectionDivider1) || (sidebar_row == kSelectionDivider2)) {
        RFSeparatorCell* separator = [tableView makeViewWithIdentifier:@"SeparatorCell" owner:self];
        return separator;
    }

    RFMenuCell* cell = [tableView makeViewWithIdentifier:@"MenuCell" owner:self];
	cell.sidebarRow = row;
	
	if (sidebar_row == kSelectionTimeline) {
		cell.titleField.stringValue = @"Timeline";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"bubble.left.and.bubble.right" accessibilityDescription:@"Timeline"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
	else if (sidebar_row == kSelectionMentions) {
		cell.titleField.stringValue = @"Mentions";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"at" accessibilityDescription:@"Mentions"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
	else if (sidebar_row == kSelectionFavorites) {
		cell.titleField.stringValue = @"Bookmarks";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"star" accessibilityDescription:@"Bookmarks"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
	else if (sidebar_row == kSelectionDiscover) {
		cell.titleField.stringValue = @"Discover";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:@"Discover"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
    else if (sidebar_row == kSelectionPosts) {
        cell.titleField.stringValue = @"Posts";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"doc" accessibilityDescription:@"Posts"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
    }
    else if (sidebar_row == kSelectionPages) {
        cell.titleField.stringValue = @"Pages";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"rectangle.stack" accessibilityDescription:@"Pages"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
    }
    else if (sidebar_row == kSelectionUploads) {
        cell.titleField.stringValue = @"Uploads";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"photo.on.rectangle" accessibilityDescription:@"Uploads"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
    }
	else if (sidebar_row == kSelectionReplies) {
		cell.titleField.stringValue = @"Replies";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"bubble.left" accessibilityDescription:@"Replies"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
	else if (sidebar_row == kSelectionBookshelves) {
		cell.titleField.stringValue = @"Bookshelves";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"books.vertical" accessibilityDescription:@"Bookshelves"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}
	else if (sidebar_row == kSelectionNotes) {
		cell.titleField.stringValue = @"Notes";
		cell.iconView.image = [NSImage rf_imageWithSystemSymbolName:@"note" accessibilityDescription:@"Notes"];
		if (self.window.isKeyWindow) {
			cell.iconView.alphaValue = 1.0;
		}
		else {
			cell.iconView.alphaValue = 0.5;
		}
	}

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	NSInteger sidebar_row = [[self.sidebarItems objectAtIndex:row] integerValue];

	if (sidebar_row == kSelectionTimeline) {
		[self showTimeline:nil];
	}
	else if (sidebar_row == kSelectionMentions) {
		[self showMentions:nil];
	}
	else if (sidebar_row == kSelectionFavorites) {
		[self showFavorites:nil];
	}
	else if (sidebar_row == kSelectionDiscover) {
		[self showDiscover:nil];
	}
    else if (sidebar_row == kSelectionDivider1) {
        // separator
        return NO;
    }
	else if (sidebar_row == kSelectionPosts) {
		[self showPosts:nil];
	}
	else if (sidebar_row == kSelectionPages) {
		[self showPages:nil];
	}
	else if (sidebar_row == kSelectionUploads) {
		[self showUploads:nil];
	}
	else if (sidebar_row == kSelectionDivider2) {
		// separator
		return NO;
	}
	else if (sidebar_row == kSelectionReplies) {
		[self showReplies:nil];
	}
	else if (sidebar_row == kSelectionBookshelves) {
		[self showBookshelves:nil];
	}
	else if (sidebar_row == kSelectionNotes) {
		[self showNotes:nil];
	}

	return YES;
}

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	NSInteger sidebar_row = [[self.sidebarItems objectAtIndex:row] integerValue];

	if ((sidebar_row == kSelectionDivider1) || (sidebar_row == kSelectionDivider2)) {
        return 10;
    }
    else {
        return tableView.rowHeight;
    }
}

#pragma mark -

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return 150;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return 200;
}

- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
	if (view == self.containerView) {
		return YES;
	}
	else {
		return NO;
	}
}

#pragma mark -

- (NSArray<NSToolbarItemIdentifier> *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return @[ @"StatusBubble", NSToolbarFlexibleSpaceItemIdentifier, @"ProfileBox", NSToolbarFlexibleSpaceItemIdentifier, @"UploadButton", NSToolbarFlexibleSpaceItemIdentifier, @"NewPost" ];
}

- (NSArray<NSToolbarItemIdentifier> *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray* items = [NSMutableArray array];
	
//	[items addObject:@"StatusBubble"];
	[items addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[items addObject:@"ProfileBox"];
	[items addObject:NSToolbarFlexibleSpaceItemIdentifier];

	if (self.selectedTimeline == kSelectionUploads) {
		[items addObject:@"UploadButton"];
		[items addObject:NSToolbarFlexibleSpaceItemIdentifier];
	}

	[items addObject:@"NewPost"];
	
	return items;
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	if ([itemIdentifier isEqualToString:@"StatusBubble"]) {
		NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		item.view = self.statusBubble;
        item.minSize = NSMakeSize(80, self.statusBubble.bounds.size.height);
        item.maxSize = self.statusBubble.bounds.size;
		return item;
	}
    else if ([itemIdentifier isEqualToString:@"ProfileBox"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = self.profileBox;
		item.bordered = NO;
        return item;
    }
    else if ([itemIdentifier isEqualToString:@"NewPost"]) {
		// for newer macOS, position image more explicitly
		if (@available(macOS 15.0, *)) {
			NSImage* button_img = [NSImage imageWithSystemSymbolName:@"square.and.pencil" accessibilityDescription:@"New Post"];
			
			NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 5, 35, 30)];
			button.image = button_img;
			button.imagePosition = NSImageOnly;
			button.target = nil;
			button.action = @selector(newDocument:);
			
			NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
			item.view = button;
			return item;
		}
		else {
			NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
			item.label = @"New Post";
			item.image = [NSImage imageWithSystemSymbolName:@"square.and.pencil" accessibilityDescription:@"New Post"];
			item.target = nil;
			item.action = @selector(newDocument:);
			return item;
		}
    }
	else if ([itemIdentifier isEqualToString:@"UploadButton"]) {
		NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		NSButton *uploadButton = [NSButton buttonWithTitle:@"Upload..." target:nil action:@selector(promptForUpload:)];
		uploadButton.bordered = YES;
		item.view = uploadButton;
		return item;
	}
    else {
        return nil;
    }
}

@end
