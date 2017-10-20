//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

#import "RFMenuCell.h"
#import "RFOptionsController.h"
#import "RFPostController.h"
#import "RFConversationController.h"
#import "RFFriendsController.h"
#import "RFUserController.h"
#import "RFRoundedImageView.h"
#import "SSKeychain.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "RFStack.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

static CGFloat const kDefaultSplitViewPosition = 170.0;

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

	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
	[self setupUser];
	[self setupNotifications];
	[self setupTimer];
}

//- (void) setupTextView
//{
//	self.textView.font = [NSFont systemFontOfSize:15 weight:NSFontWeightLight];
//	self.textView.backgroundColor = [NSColor colorWithCalibratedWhite:0.973 alpha:1.000];
//}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"MenuCell" bundle:nil] forIdentifier:@"MenuCell"];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
}

- (void) setupSplitView
{
	[self.splitView setPosition:kDefaultSplitViewPosition ofDividerAtIndex:0];
	self.splitView.delegate = self;
}

- (void) setupWebView
{
	self.messageTopConstraint.constant = -35;
	self.webView.policyDelegate = self;

	[self showTimeline:nil];
}

- (void) setupUser
{
	NSString* full_name = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountFullName"];
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* gravatar_url = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountGravatarURL"];
	
	self.fullNameField.stringValue = full_name;
	self.usernameField.stringValue = [NSString stringWithFormat:@"@%@", username];
	[self.profileImageView loadFromURL:gravatar_url];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidScroll:) name:NSScrollViewWillStartLiveScrollNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPostingNotification:) name:kOpenPostingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasFavoritedNotification:) name:kPostWasFavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasUnfavoritedNotification:) name:kPostWasUnfavoritedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showConversationNotification:) name:kShowConversationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(popNavigationNotification:) name:kPopNavigationNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showUserFollowingNotification:) name:kShowUserFollowingNotification object:nil];
}

- (void) setupTimer
{
	self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkSeconds.floatValue target:self selector:@selector(checkPostsFromTimer:) userInfo:nil repeats:NO];
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
	[self newDocument:nil];
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

	RFConversationController* controller = [[RFConversationController alloc] initWithPostID:post_id];
	controller.webView.policyDelegate = self;

	[self pushViewController:controller];
}

- (void) showUserFollowingNotification:(NSNotification *)notification
{
	NSString* username = [notification.userInfo objectForKey:kShowUserFollowingUsernameKey];

	RFFriendsController* controller = [[RFFriendsController alloc] initWithUsername:username];
	controller.webView.policyDelegate = self;

	[self pushViewController:controller];
}

- (void) popNavigationNotification:(NSNotification *)notification
{
	[self popViewController];
}

#pragma mark -

- (IBAction) newDocument:(id)sender
{
	[self hideOptionsMenu];

	BOOL has_hosted = [[NSUserDefaults standardUserDefaults] boolForKey:@"HasSnippetsBlog"];
	NSString* micropub = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalMicropubMe"];
	NSString* xmlrpc = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalBlogEndpoint"];
	if (has_hosted || micropub || xmlrpc) {
		if (!self.postController) {
			RFPostController* controller = [[RFPostController alloc] init];
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
		[self.postController.view removeFromSuperview];
		self.postController = nil;
	}];
}

- (IBAction) showTimeline:(id)sender
{
	self.selectedTimeline = kSelectionTimeline;

	[self closeOverlays];

	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* token = [SSKeychain passwordForService:@"Micro.blog" account:username];
	
	CGFloat scroller_width = 0;
	if (NSScroller.preferredScrollerStyle == NSScrollerStyleLegacy) {
		scroller_width = [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy];
	}
	CGFloat pane_width = self.webView.bounds.size.width;
	int timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width - scroller_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (IBAction) showMentions:(id)sender
{
	self.selectedTimeline = kSelectionMentions;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
}

- (IBAction) showFavorites:(id)sender
{
	self.selectedTimeline = kSelectionFavorites;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
}

- (IBAction) showDiscover:(id)sender
{
	self.selectedTimeline = kSelectionDiscover;

	[self closeOverlays];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/discover"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:3] byExtendingSelection:NO];
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

	RFDispatchSeconds (1.5, ^{
		self.messageTopConstraint.animator.constant = -35;
		[self.messageSpinner stopAnimation:nil];
	});
}

- (IBAction) signOut:(id)sender
{
	NSString* microblog_username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* external_username = [[NSUserDefaults standardUserDefaults] stringForKey:@"ExternalBlogUsername"];

	[SSKeychain deletePasswordForService:@"Micro.blog" account:microblog_username];
	[SSKeychain deletePasswordForService:@"ExternalBlog" account:external_username];
	[SSKeychain deletePasswordForService:@"MicropubBlog" account:@"default"];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AccountUsername"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AccountGravatarURL"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AccountDefaultSite"];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HasSnippetsBlog"];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogUsername"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogApp"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogEndpoint"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogID"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogIsPreferred"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalBlogURL"];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalMicropubMe"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalMicropubTokenEndpoint"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalMicropubPostingEndpoint"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalMicropubMediaEndpoint"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ExternalMicropubState"];

//	[Answers logCustomEventWithName:@"Sign Out" customAttributes:nil];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RFSignOut" object:self];
}

#pragma mark -

- (void) checkPostsFromTimer:(NSTimer *)timer
{
	if (self.selectedTimeline == kSelectionTimeline) {
		NSString* top_post_id = [self topPostID];
		if (top_post_id.length > 0) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/posts/check"];
			NSDictionary* args = @{ @"since_id": top_post_id };
			[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
				NSNumber* count = [response.parsedResponse objectForKey:@"count"];
				NSNumber* check_seconds = [response.parsedResponse objectForKey:@"check_seconds"];
				if (count.integerValue > 0) {
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

				if (check_seconds.integerValue > 2) { // sanity check value
					self.checkSeconds = check_seconds;
				}
			}];
		}
	}

	[self setupTimer];
}

- (void) closeOverlays
{
	[self popToRootViewController];
	
	[self.optionsPopover performClose:nil];
	self.optionsPopover = nil;

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
	else {
		return self.webView;
	}
}

- (void) pushViewController:(NSViewController *)controller
{
	[self.navigationStack push:controller];

	NSRect pushed_final_r = self.containerView.bounds;
	pushed_final_r.origin.x = kDefaultSplitViewPosition + 1;

	NSRect pushed_start_r = self.containerView.bounds;
	pushed_start_r.origin.x = kDefaultSplitViewPosition + 1 + self.containerView.bounds.size.width;

	NSRect top_r = self.containerView.frame;
	top_r.origin.x = top_r.origin.x - self.containerView.bounds.size.width - 1;

	controller.view.frame = pushed_start_r;

	[self.window.contentView addSubview:controller.view positioned:NSWindowAbove relativeTo:self.webView];

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
		controller.view.animator.frame = pushed_final_r;
		self.webView.animator.frame = top_r;
	} completionHandler:^{
	}];
}

- (void) popViewController
{
	NSViewController* controller = [self.navigationStack pop];
	if (controller) {
		NSRect back_final_r = controller.view.frame;

		NSRect pushed_final_r = controller.view.frame;
		pushed_final_r.origin.x = kDefaultSplitViewPosition + 1 + self.webView.bounds.size.width;

		[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
			controller.view.animator.frame = pushed_final_r;
			self.webView.animator.frame = back_final_r;
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

- (void) showPostController:(RFPostController *)controller
{
	self.postController = controller;

	NSRect r = self.webView.bounds;
	r.origin.x = kDefaultSplitViewPosition + 1;
	self.postController.view.frame = r;
	self.postController.view.alphaValue = 0.0;
	
	[self.window.contentView addSubview:self.postController.view positioned:NSWindowAbove relativeTo:[self currentWebView]];

	self.postController.view.animator.alphaValue = 1.0;
	[self.window makeFirstResponder:self.postController.textView];
	self.postController.nextResponder = self;
}

- (void) showProfileWithUsername:(NSString *)username
{
	[self hideOptionsMenu];
	
	RFUserController* user_controller = [[RFUserController alloc] initWithUsername:username];
	user_controller.webView.policyDelegate = self;

	[self pushViewController:user_controller];
}

- (void) showReplyWithPostID:(NSString *)postID username:(NSString *)username
{
	RFPostController* controller = [[RFPostController alloc] initWithPostID:postID username:username];
	[self showPostController:controller];
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
	NSString* scroll_js = [NSString stringWithFormat:@"$('body').scrollTop();"];

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
		NSString* username = [path stringByReplacingOccurrencesOfString:@"/" withString:@""];
		if (username.length > 0) {
			found_microblog_url = YES;
			[self showProfileWithUsername:username];
		}
	}
	
	if (!found_microblog_url) {
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

#pragma mark -

- (void) webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if ([[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue] == WebNavigationTypeLinkClicked) {
		[self showURL:request.URL];
		[listener ignore];
	}
	else if ([request.URL.scheme isEqualToString:@"microblog"]) {
		[[NSWorkspace sharedWorkspace] openURL:request.URL];
		[listener ignore];
	}
	else {
		[listener use];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return 4;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFMenuCell* cell = [tableView makeViewWithIdentifier:@"MenuCell" owner:self];
	
	if (row == 0) {
		cell.titleField.stringValue = @"Timeline";
	}
	else if (row == 1) {
		cell.titleField.stringValue = @"Mentions";
	}
	else if (row == 2) {
		cell.titleField.stringValue = @"Favorites";
	}
	else if (row == 3) {
		cell.titleField.stringValue = @"Discover";
	}
	else if (row == 4) {
		cell.titleField.stringValue = @"Drafts";
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

	return YES;
}

#pragma mark -

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

- (NSRect) splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	return NSZeroRect;
}

@end
