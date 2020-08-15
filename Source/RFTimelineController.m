//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

#import "RFMenuCell.h"
#import "RFSeparatorCell.h"
#import "RFOptionsController.h"
#import "RFPostController.h"
#import "RFPostWindowController.h"
#import "RFAllPostsController.h"
#import "RFAllUploadsController.h"
#import "RFConversationController.h"
#import "RFFriendsController.h"
#import "RFTopicController.h"
#import "RFUserController.h"
#import "RFRoundedImageView.h"
#import "SAMKeychain.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "RFAccount.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "RFPost.h"
#import "RFStack.h"
#import "NSAppearance+Extras.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <QuartzCore/QuartzCore.h>

//static CGFloat const kDefaultSplitViewPosition = 170.0;

@implementation RFTimelineController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Timeline"];
	if (self) {
		self.navigationStack = [[RFStack alloc] init];
		self.checkSeconds = @5;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupToolbar];
	[self setupFullScreen];
	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
	[self setupUser];
	[self setupNotifications];
	[self setupTimer];
}

- (void) setupToolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"TimelineToolbar"];

    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setDelegate:self];
    
    [self.window setToolbar:toolbar];
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
	[self.splitView setAutosaveName:@"TimelineSplitView"];
	self.splitView.delegate = self;
//	[self.splitView setPosition:kDefaultSplitViewPosition ofDividerAtIndex:0];
	[self.splitView setHoldingPriority:NSLayoutPriorityRequired forSubviewAtIndex:0];
}

- (void) setupWebView
{
	self.messageTopConstraint.constant = -35;
	
	[self setupWebDelegates:self.webView];
	[self.webView setDrawsBackground:![NSAppearance rf_isDarkMode]];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPostingNotification:) name:kOpenPostingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasFavoritedNotification:) name:kPostWasFavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasUnfavoritedNotification:) name:kPostWasUnfavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showConversationNotification:) name:kShowConversationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sharePostNotification:) name:kSharePostNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(popNavigationNotification:) name:kPopNavigationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showUserFollowingNotification:) name:kShowUserFollowingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTimelineNotification:) name:kRefreshTimelineNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchAccountNotification:) name:kSwitchAccountNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountsNotification:) name:kRefreshAccountsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeAppearanceDidChangeNotification:) name:kDarkModeAppearanceDidChangeNotification object:nil];

//	[NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
}

- (void) setupTimer
{
	self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkSeconds.floatValue target:self selector:@selector(checkPostsFromTimer:) userInfo:nil repeats:NO];
	self.checkSeconds = @120; // in case it fails, bump to higher default
}

#pragma mark -

- (void) timelineDidScroll:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSView class]]) {
		NSView* view = (NSView *)notification.object;
		if ([view isDescendantOf:[self currentWebView]]) {
			[self hideOptionsMenu];
		}
	}
}

- (void) openPostingNotification:(NSNotification *)notification
{
	RFPost* post = [notification.userInfo objectForKey:kOpenPostingPostKey];
	[self showEditPost:post];
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

- (void) refreshTimelineNotification:(NSNotification *)notification
{
	[self refreshTimeline:nil];
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

#pragma mark -

- (IBAction) newDocument:(id)sender
{
	[self showEditPost:nil];
}

- (IBAction) newPage:(id)sender
{
	[self hideOptionsMenu];

	BOOL has_hosted = [RFSettings boolForKey:kHasSnippetsBlog];
	NSString* micropub = [RFSettings stringForKey:kExternalMicropubMe];
	NSString* xmlrpc = [RFSettings stringForKey:kExternalBlogEndpoint];
	if (has_hosted || micropub || xmlrpc) {
		if (!self.postController) {
			RFPostController* controller = [[RFPostController alloc] initWithChannel:@"pages"];
			[self showPostController:controller];
		}
	}
	else {
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"No hosted or external blog configured."];
		[alert setInformativeText:@"Add a hosted blog on Micro.blog to post to, or sign in to a WordPress or compatible weblog in the preferences window."];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		}];
	}
}

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

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1&fontsize=%ld&darkmode=%ld&fontsystem=1", token, pane_width - scroller_width, timezone_minutes, (long)text_size, darkmode];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	self.webView.hidden = NO;
	
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (IBAction) showMentions:(id)sender
{
	self.selectedTimeline = kSelectionMentions;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	self.webView.hidden = NO;

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
}

- (IBAction) showFavorites:(id)sender
{
	self.selectedTimeline = kSelectionFavorites;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	self.webView.hidden = NO;

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
}

- (IBAction) showDiscover:(id)sender
{
	self.selectedTimeline = kSelectionDiscover;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/discover"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	self.webView.hidden = NO;

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:3] byExtendingSelection:NO];
}

- (IBAction) showPosts:(id)sender
{
	self.selectedTimeline = kSelectionPosts;

	[self closeOverlays];

	RFAllPostsController* controller = [[RFAllPostsController alloc] initShowingPages:NO];
	[self showAllPostsController:controller];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:5] byExtendingSelection:NO];
}

- (IBAction) showPages:(id)sender
{
	self.selectedTimeline = kSelectionPosts;

	[self closeOverlays];

	RFAllPostsController* controller = [[RFAllPostsController alloc] initShowingPages:YES];
	[self showAllPostsController:controller];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:6] byExtendingSelection:NO];
}

- (IBAction) showUploads:(id)sender
{
	self.selectedTimeline = kSelectionPosts;

	[self closeOverlays];

	RFAllUploadsController* controller = [[RFAllUploadsController alloc] init];
	[self showAllPostsController:controller];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:7] byExtendingSelection:NO];
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
		[self.allPostsController fetchPosts];
	}

	RFDispatchSeconds (1.5, ^{
		self.messageTopConstraint.animator.constant = -35;
		[self.messageSpinner stopAnimation:nil];
	});
}

- (IBAction) signOut:(id)sender
{
	for (RFAccount* a in [RFSettings accounts]) {
		NSString* microblog_username = [RFSettings stringForKey:kAccountUsername account:a];
		NSString* external_username = [RFSettings stringForKey:kExternalBlogUsername account:a];

		[SAMKeychain deletePasswordForService:@"Micro.blog" account:microblog_username];
		[SAMKeychain deletePasswordForService:@"ExternalBlog" account:external_username];
		[SAMKeychain deletePasswordForService:@"MicropubBlog" account:@"default"];

		[RFSettings removeObjectForKey:kAccountUsername account:a];
		[RFSettings removeObjectForKey:kAccountGravatarURL account:a];
		[RFSettings removeObjectForKey:kAccountDefaultSite account:a];

		[RFSettings removeObjectForKey:kHasSnippetsBlog account:a];

		[RFSettings removeObjectForKey:kExternalBlogUsername account:a];
		[RFSettings removeObjectForKey:kExternalBlogApp account:a];
		[RFSettings removeObjectForKey:kExternalBlogEndpoint account:a];
		[RFSettings removeObjectForKey:kExternalBlogID account:a];
		[RFSettings removeObjectForKey:kExternalBlogIsPreferred account:a];
		[RFSettings removeObjectForKey:kExternalBlogURL account:a];

		[RFSettings removeObjectForKey:kExternalMicropubMe account:a];
		[RFSettings removeObjectForKey:kExternalMicropubTokenEndpoint account:a];
		[RFSettings removeObjectForKey:kExternalMicropubPostingEndpoint account:a];
		[RFSettings removeObjectForKey:kExternalMicropubMediaEndpoint account:a];
		[RFSettings removeObjectForKey:kExternalMicropubState account:a];
	}
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentUsername];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kAccountUsernames];
	[RFAccount clearCache];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RFSignOut" object:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(performFindPanelAction:)) {
		if ((item.tag == NSTextFinderActionShowFindInterface) && (self.selectedTimeline == kSelectionPosts)) {
			return YES;
		}
		else {
			return NO;
		}
	}
	else {
		return YES;
	}
}

- (void) performFindPanelAction:(id)sender
{
	if (self.selectedTimeline == kSelectionPosts) {
		[self.allPostsController focusSearch];
	}
}

#pragma mark -

- (void) checkPostsFromTimer:(NSTimer *)timer
{
	if (self.selectedTimeline == kSelectionTimeline) {
//		[self showNotificationWithTitle:@"Some User (@manton)" text:@"@manton Hello hello"];

		NSString* top_post_id = [self topPostID];
		if (top_post_id.length > 0) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/posts/check"];
			NSDictionary* args = @{ @"since_id": top_post_id };
			[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
					NSNumber* count = [response.parsedResponse objectForKey:@"count"];
					NSNumber* check_seconds = [response.parsedResponse objectForKey:@"check_seconds"];
					if (count && count.integerValue > 0) {
						NSString* msg;
						if (count.integerValue == 1) {
							msg = @"1 new post";
						}
						else {
							msg = [NSString stringWithFormat:@"%@ new posts", count];
						}

						RFDispatchMainAsync (^{
							self.messageField.stringValue = msg;
							self.messageTopConstraint.animator.constant = -1;
						});
					}
					else {
						RFDispatchMainAsync (^{
							self.messageTopConstraint.animator.constant = -35;
							[self.messageSpinner stopAnimation:nil];
						});
					}

					if (check_seconds && check_seconds.integerValue > 2) { // sanity check value
						self.checkSeconds = check_seconds;
					}
				}
			}];
		}
	}

	[self setupTimer];
}

- (void) closeOverlays
{
	self.webView.hidden = YES;
	[self popToRootViewController];
	
	[self.optionsPopover performClose:nil];
	self.optionsPopover = nil;

	self.messageTopConstraint.animator.constant = -35;
	[self.messageSpinner stopAnimation:nil];

	if (self.allPostsController) {
		[self.allPostsController.view removeFromSuperview];
		self.allPostsController = nil;
	}

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
	else {
		return self.webView;
	}
}

- (void) pushViewController:(NSViewController *)controller
{
	if ([self.navigationStack count] == 0) {
		self.navigationLeftConstraint = self.timelineLeftConstraint;
		self.navigationRightConstraint = self.timelineRightConstraint;
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

	NSView* last_view = [self currentContainerView];
	[self.navigationStack push:controller];
	controller.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.window.contentView addSubview:controller.view positioned:NSWindowBelow relativeTo:self.webView];

	[self addFixedConstraintsToView:controller.view containerView:last_view];
	[controller.view setNeedsLayout:YES];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
		context.duration = 0.3;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
		self.navigationLeftConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
		self.navigationRightConstraint.animator.constant = [self.navigationStack count] * self.containerView.bounds.size.width;
	} completionHandler:^{
		// after animating, temporary pin to right
		self.navigationRightConstraint.active = NO;
		self.navigationPinnedConstraint.active = YES;
	}];
}

- (void) popViewController
{
	NSViewController* controller = [self.navigationStack pop];
	if (controller) {
		// restore fixed constraint
		self.navigationRightConstraint.active = YES;
		self.navigationPinnedConstraint.active = NO;

		[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
			context.duration = 0.3;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
			self.navigationLeftConstraint.animator.constant = [self.navigationStack count] * (-self.containerView.bounds.size.width);
			self.navigationRightConstraint.animator.constant = [self.navigationStack count] * self.containerView.bounds.size.width;
		} completionHandler:^{
			[controller.view removeFromSuperview];
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

	NSLayoutConstraint* right_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0];
	right_constraint.priority = NSLayoutPriorityDefaultHigh;
	right_constraint.active = YES;

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

- (void) showPostController:(RFPostController *)controller
{
	if (YES) {
		RFPostWindowController* window_controller = [[RFPostWindowController alloc] initWithPostController:controller];
		[window_controller showWindow:nil];
	}
	else {
		self.postController = controller;

		NSRect r = self.webView.bounds;
	//	r.origin.x = kDefaultSplitViewPosition + 1;
		self.postController.view.frame = r;
		self.postController.view.alphaValue = 0.0;
		
		self.postController.view.translatesAutoresizingMaskIntoConstraints = NO;
		[self.window.contentView addSubview:self.postController.view positioned:NSWindowAbove relativeTo:[self currentWebView]];

		self.postController.view.animator.alphaValue = 1.0;
		[self.window makeFirstResponder:self.postController.textView];
		self.postController.nextResponder = self;
		[self addResizeConstraintsToOverlay:self.postController.view containerView:self.containerView];
	}
}

- (void) showAllPostsController:(RFAllPostsController *)controller
{
	self.allPostsController = controller;

	NSRect r = self.webView.bounds;
//	r.origin.x = kDefaultSplitViewPosition + 1;
	self.allPostsController.view.frame = r;
	self.allPostsController.view.alphaValue = 0.0;
	
	self.allPostsController.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.window.contentView addSubview:self.allPostsController.view positioned:NSWindowAbove relativeTo:[self currentWebView]];

	self.allPostsController.view.animator.alphaValue = 1.0;
	self.allPostsController.nextResponder = self;
	[self addResizeConstraintsToOverlay:self.allPostsController.view containerView:self.containerView];
}

- (void) showTopicsWithSearch:(NSString *)term
{
	[self hideOptionsMenu];
	
	RFTopicController* controller = [[RFTopicController alloc] initWithTopic:term];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) showConversationWithPostID:(NSString *)postID
{
	RFConversationController* controller = [[RFConversationController alloc] initWithPostID:postID];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) showShareWithPostID:(NSString *)postID
{
	[self hideOptionsMenu];

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
	[self hideOptionsMenu];
	
	RFUserController* controller = [[RFUserController alloc] initWithUsername:username];
	[controller view];
	[self setupWebDelegates:controller.webView];

	[self pushViewController:controller];
}

- (void) showPostWithText:(NSString *)text
{
	if (!self.postController) {
		RFPostController* controller = [[RFPostController alloc] initWithText:text];
		[self showPostController:controller];
	}
}

- (void) showReplyWithPostID:(NSString *)postID username:(NSString *)username
{
	if (!self.postController) {
		RFPostController* controller = [[RFPostController alloc] initWithPostID:postID username:username];
		[self showPostController:controller];
	}
}

- (void) showOptionsMenuWithPostID:(NSString *)postID
{
	if (self.optionsPopover) {
		[self hideOptionsMenu];
	}
	else {
		[self setSelected:YES withPostID:postID];
		NSString* username = [self usernameOfPostID:postID];
		RFOptionsPopoverType popover_type = [self popoverTypeOfPostID:postID];

		RFOptionsController* options_controller = [[RFOptionsController alloc] initWithPostID:postID username:username popoverType:popover_type];
		
		self.optionsPopover = [[NSPopover alloc] init];
		self.optionsPopover.contentViewController = options_controller;

		NSRect r = [self rectOfPostID:postID];
		[self.optionsPopover showRelativeToRect:r ofView:[self currentWebView] preferredEdge:NSRectEdgeMinY];
	}
}

- (void) hideOptionsMenu
{
	if (self.optionsPopover) {
		RFOptionsController* options_controller = (RFOptionsController *)self.optionsPopover.contentViewController;
		[self setSelected:NO withPostID:options_controller.postID];
		
		[self.optionsPopover performClose:nil];
		self.optionsPopover = nil;
	}
}

- (void) showEditPost:(RFPost *)post
{
	[self hideOptionsMenu];

	BOOL has_hosted = [RFSettings boolForKey:kHasSnippetsBlog];
	NSString* micropub = [RFSettings stringForKey:kExternalMicropubMe];
	NSString* xmlrpc = [RFSettings stringForKey:kExternalBlogEndpoint];
	if (has_hosted || micropub || xmlrpc) {
		if (!self.postController) {
			RFPostController* controller;
			if (post) {
				controller = [[RFPostController alloc] initWithPost:post];
			}
			else {
				controller = [[RFPostController alloc] init];
			}
			[self showPostController:controller];
		}
	}
	else {
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"No hosted or external blog configured."];
		[alert setInformativeText:@"Add a hosted blog on Micro.blog to post to, or sign in to a WordPress or compatible weblog in the preferences window."];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		}];
	}
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
	NSString* post_id = [self.webView stringByEvaluatingJavaScriptFromString:js];
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

- (NSString *) linkOfPostID:(NSString *)postID
{
	NSString* username_js = [NSString stringWithFormat:@"$('#post_%@').find('.post_link').text();", postID];
	NSString* username_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:username_js];
	return [username_s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (RFOptionsPopoverType) popoverTypeOfPostID:(NSString *)postID
{
	NSString* is_favorite_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_favorite');", postID];
	NSString* is_deletable_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_deletable');", postID];

	NSString* is_favorite_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:is_favorite_js];
	NSString* is_deletable_s = [[self currentWebView] stringByEvaluatingJavaScriptFromString:is_deletable_js];

	if ([is_favorite_s boolValue]) {
		return kOptionsPopoverWithUnfavorite;
	}
	else if ([is_deletable_s boolValue]) {
		return kOptionsPopoverWithDelete;
	}
	else {
		return kOptionsPopoverDefault;
	}
}

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

#pragma mark -

- (void) webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame
{
	NSScrollView* scrollview = webView.mainFrame.frameView.documentView.enclosingScrollView;
	[scrollview setVerticalScrollElasticity:NSScrollElasticityAllowed];
	[scrollview setHorizontalScrollElasticity:NSScrollElasticityNone];
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
	if ([RFSettings hasSnippetsBlog] && ![RFSettings prefersExternalBlog]) {
		return 8;
	}
	else {
		return 4;
	}
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if (row == 4) {
        RFSeparatorCell* separator = [tableView makeViewWithIdentifier:@"SeparatorCell" owner:self];
        return separator;
    }

    RFMenuCell* cell = [tableView makeViewWithIdentifier:@"MenuCell" owner:self];
	
	if (row == 0) {
		cell.titleField.stringValue = @"Timeline";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"bubble.left.and.bubble.right" accessibilityDescription:@"Timeline"];
	}
	else if (row == 1) {
		cell.titleField.stringValue = @"Mentions";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"quote.bubble" accessibilityDescription:@"Mentions"];
	}
	else if (row == 2) {
		cell.titleField.stringValue = @"Bookmarks";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"star" accessibilityDescription:@"Bookmarks"];
	}
	else if (row == 3) {
		cell.titleField.stringValue = @"Discover";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:@"Discover"];
	}
    else if (row == 5) {
        cell.titleField.stringValue = @"Posts";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:@"Posts"];
    }
    else if (row == 6) {
        cell.titleField.stringValue = @"Pages";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"rectangle.stack" accessibilityDescription:@"Pages"];
    }
    else if (row == 7) {
        cell.titleField.stringValue = @"Uploads";
        cell.iconView.image = [NSImage imageWithSystemSymbolName:@"photo.on.rectangle" accessibilityDescription:@"Uploads"];
    }

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	if (row == 0) {
		[self showTimeline:nil];
	}
	else if (row == 1) {
		[self showMentions:nil];
	}
	else if (row == 2) {
		[self showFavorites:nil];
	}
	else if (row == 3) {
		[self showDiscover:nil];
	}
    else if (row == 4) {
        // separator
        return NO;
    }
	else if (row == 5) {
		[self showPosts:nil];
	}
	else if (row == 6) {
		[self showPages:nil];
	}
	else if (row == 7) {
		[self showUploads:nil];
	}

	return YES;
}

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if (row == 4) {
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
//	return kDefaultSplitViewPosition;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return 300;
//	return kDefaultSplitViewPosition;
}

//- (CGFloat) splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
//{
//	if (dividerIndex == 0) {
//		return kDefaultSplitViewPosition;
//	}
//	else {
//		return proposedPosition;
//	}
//}

- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
	if (view == self.containerView) {
		return YES;
	}
	else {
		return NO;
	}
}

//- (NSRect) splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
//{
//	return NSZeroRect;
//}

#pragma mark -

- (NSArray<NSToolbarItemIdentifier> *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return @[ @"ProfileBox", NSToolbarFlexibleSpaceItemIdentifier, @"NewPost" ];
}

- (NSArray<NSToolbarItemIdentifier> *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return @[ @"ProfileBox", NSToolbarFlexibleSpaceItemIdentifier, @"NewPost" ];
}

- ( NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    if ([itemIdentifier isEqualToString:@"ProfileBox"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = self.profileBox;
        return item;
    }
    else if ([itemIdentifier isEqualToString:@"Separator"]) {
        NSToolbarItem* separator = [NSTrackingSeparatorToolbarItem trackingSeparatorToolbarItemWithIdentifier:itemIdentifier splitView:self.splitView dividerIndex:0];
        return separator;
    }
    else if ([itemIdentifier isEqualToString:@"NewPost"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.image = [NSImage imageWithSystemSymbolName:@"square.and.pencil" accessibilityDescription:@"New Post"];
        item.target = self;
        item.action = @selector(newDocument:);
        return item;
    }
    else {
        return nil;
    }
}

@end
