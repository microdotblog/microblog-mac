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
#import "RFRoundedImageView.h"
#import "SSKeychain.h"
#import "RFConstants.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

static CGFloat const kDefaultSplitViewPosition = 170.0;

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

	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
	[self setupUser];
	[self setupNotifications];
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
}

#pragma mark -

- (void) timelineDidScroll:(NSNotification *)notification
{
	if ([notification.object isKindOfClass:[NSView class]]) {
		NSView* view = (NSView *)notification.object;
		if ([view isDescendantOf:self.webView]) {
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
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) postWasUnfavoritedNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kPostNotificationPostIDKey];
	NSString* js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_favorite');", post_id];
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) showConversationNotification:(NSNotification *)notification
{
	NSString* post_id = [notification.userInfo objectForKey:kPostNotificationPostIDKey];
	
	// ...
	
	self.conversationController = [[RFConversationController alloc] init];
	[self pushController:self.conversationController];
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

	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* token = [SSKeychain passwordForService:@"Micro.blog" account:username];
	
	CGFloat pane_width = self.webView.bounds.size.width;
	int timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
	self.optionsPopover = nil;

	[self performClose:nil];
}

- (IBAction) showMentions:(id)sender
{
	self.selectedTimeline = kSelectionMentions;

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
	self.optionsPopover = nil;

	[self performClose:nil];
}

- (IBAction) showFavorites:(id)sender
{
	self.selectedTimeline = kSelectionFavorites;

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
	self.optionsPopover = nil;

	[self performClose:nil];
}

- (IBAction) refreshTimeline:(id)sender
{
	if (self.selectedTimeline == kSelectionTimeline) {
		[self showTimeline:nil];
	}
	else if (self.selectedTimeline == kSelectionMentions) {
		[self showMentions:nil];
	}
	else if (self.selectedTimeline == kSelectionFavorites) {
		[self showFavorites:nil];
	}
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

	[Answers logCustomEventWithName:@"Sign Out" customAttributes:nil];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RFSignOut" object:self];
}

- (void) pushController:(NSViewController *)controller
{
//	self.topController = controller;

	NSRect pushed_final_r = self.webView.bounds;
	pushed_final_r.origin.x = kDefaultSplitViewPosition + 1;

	NSRect pushed_start_r = self.webView.bounds;
	pushed_start_r.origin.x = kDefaultSplitViewPosition + 1 + self.webView.bounds.size.width;

	NSRect top_r = self.webView.frame;
	top_r.origin.x = top_r.origin.x - self.webView.bounds.size.width - 1;

	controller.view.frame = pushed_start_r;

	[self.window.contentView addSubview:controller.view positioned:NSWindowAbove relativeTo:self.webView];

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
		controller.view.animator.frame = pushed_final_r;
		self.webView.animator.frame = top_r;
	} completionHandler:^{
	}];
}

- (void) showPostController:(RFPostController *)controller
{
	self.postController = controller;

	NSRect r = self.webView.bounds;
	r.origin.x = kDefaultSplitViewPosition + 1;
	self.postController.view.frame = r;
	self.postController.view.alphaValue = 0.0;
	
	[self.window.contentView addSubview:self.postController.view positioned:NSWindowAbove relativeTo:self.webView];

	self.postController.view.animator.alphaValue = 1.0;
	[self.window makeFirstResponder:self.postController.textView];
	self.postController.nextResponder = self;
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
		[self.optionsPopover showRelativeToRect:r ofView:self.webView preferredEdge:NSRectEdgeMinY];
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

- (void) setSelected:(BOOL)isSelected withPostID:(NSString *)postID
{
	NSString* js;
	if (isSelected) {
		js = [NSString stringWithFormat:@"$('#post_%@').addClass('is_selected');", postID];
	}
	else {
		js = [NSString stringWithFormat:@"$('#post_%@').removeClass('is_selected');", postID];
	}
	[self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (NSRect) rectOfPostID:(NSString *)postID
{
	NSString* top_js = [NSString stringWithFormat:@"$('#post_%@').position().top;", postID];
	NSString* height_js = [NSString stringWithFormat:@"$('#post_%@').height();", postID];
	NSString* scroll_js = [NSString stringWithFormat:@"$('body').scrollTop();"];

	NSString* top_s = [self.webView stringByEvaluatingJavaScriptFromString:top_js];
	NSString* height_s = [self.webView stringByEvaluatingJavaScriptFromString:height_js];
	NSString* scroll_s = [self.webView stringByEvaluatingJavaScriptFromString:scroll_js];

	CGFloat top_f = self.webView.bounds.size.height - [top_s floatValue] - [height_s floatValue];
	top_f += [scroll_s floatValue];
	
	// adjust to full cell width
	CGFloat left_f = 0.0;
	CGFloat width_f = self.webView.bounds.size.width;
	
	return NSMakeRect (left_f, top_f, width_f, [height_s floatValue]);
}

- (NSString *) usernameOfPostID:(NSString *)postID
{
	NSString* username_js = [NSString stringWithFormat:@"$('#post_%@').find('.post_username').text();", postID];
	NSString* username_s = [self.webView stringByEvaluatingJavaScriptFromString:username_js];
	return [username_s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *) linkOfPostID:(NSString *)postID
{
	NSString* username_js = [NSString stringWithFormat:@"$('#post_%@').find('.post_link').text();", postID];
	NSString* username_s = [self.webView stringByEvaluatingJavaScriptFromString:username_js];
	return [username_s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (RFOptionsPopoverType) popoverTypeOfPostID:(NSString *)postID
{
	NSString* is_favorite_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_favorite');", postID];
	NSString* is_deletable_js = [NSString stringWithFormat:@"$('#post_%@').hasClass('is_deletable');", postID];

	NSString* is_favorite_s = [self.webView stringByEvaluatingJavaScriptFromString:is_favorite_js];
	NSString* is_deletable_s = [self.webView stringByEvaluatingJavaScriptFromString:is_deletable_js];

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
			[[NSNotificationCenter defaultCenter] postNotificationName:kShowUserProfileNotification object:self userInfo:@{ kShowUserProfileUsernameKey: username }];
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
	return 3;
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

@end
