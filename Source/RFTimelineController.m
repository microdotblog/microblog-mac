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
#import "SSKeychain.h"
#import "RFConstants.h"

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
	[self showTimeline:nil];
}

- (void) setupUser
{
	NSString* full_name = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountFullName"];
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* gravatar_url = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountGravatarURL"];
	
	self.fullNameField.stringValue = full_name;
	self.usernameField.stringValue = [NSString stringWithFormat:@"@%@", username];
}

#pragma mark -

- (IBAction) newDocument:(id)sender
{
	RFPostController* controller = [[RFPostController alloc] init];
	[self showPostController:controller];
}

- (IBAction) performClose:(id)sender
{
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		self.postController.view.animator.alphaValue = 0.0;
	} completionHandler:^{
		[self.postController.view removeFromSuperview];
	}];
}

- (IBAction) showTimeline:(id)sender
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* token = [SSKeychain passwordForService:@"Micro.blog" account:username];
	
	CGFloat pane_width = self.webView.bounds.size.width;
	int timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
	[self performClose:nil];
}

- (IBAction) showMentions:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
}

- (IBAction) showFavorites:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
}

- (IBAction) signOut:(id)sender
{
	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	[SSKeychain deletePasswordForService:@"Micro.blog" account:username];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AccountUsername"];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"RFSignOut" object:self];
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
	RFOptionsController* options_controller;
	
	if (self.optionsPopover) {
		options_controller = (RFOptionsController *)self.optionsPopover.contentViewController;
		[self setSelected:NO withPostID:options_controller.postID];
		
		[self.optionsPopover performClose:nil];
		self.optionsPopover = nil;
	}
	else {
		[self setSelected:YES withPostID:postID];
		NSString* username = [self usernameOfPostID:postID];

		options_controller = [[RFOptionsController alloc] initWithPostID:postID username:username popoverType:kOptionsPopoverDefault];
		self.optionsPopover = [[NSPopover alloc] init];
		self.optionsPopover.contentViewController = options_controller;

		NSRect r = [self rectOfPostID:postID];
		[self.optionsPopover showRelativeToRect:r ofView:self.webView preferredEdge:NSRectEdgeMinY];
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
