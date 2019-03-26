//
//  RFAllPostsController.m
//  Snippets
//
//  Created by Manton Reece on 3/23/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFAllPostsController.h"

#import "RFPostCell.h"
#import "RFPost.h"
#import "RFBlogsController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "UUDate.h"
#import "NSString+Extras.h"

@implementation RFAllPostsController

- (id) init
{
	self = [super initWithNibName:@"AllPosts" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupBlogName];
	[self setupNotifications];
	
	[self fetchPosts];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;
}

- (void) setupBlogName
{
	NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
	if (s) {
		self.blogNameButton.title = s;
	}
	else {
		self.blogNameButton.title = [RFSettings stringForKey:kAccountDefaultSite];
	}
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
}

- (void) fetchPosts
{
	self.allPosts = @[];
	self.currentPosts = @[];
	self.blogNameButton.hidden = YES;
	[self.progressSpinner startAnimation:nil];

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFPost* post = [[RFPost alloc] init];
				NSDictionary* props = [item objectForKey:@"properties"];
				post.title = [[props objectForKey:@"name"] firstObject];
				post.text = [[props objectForKey:@"content"] firstObject];

				NSString* date_s = [[props objectForKey:@"published"] firstObject];
				post.postedAt = [NSDate uuDateFromRfc3339String:date_s];

				NSString* status = [[props objectForKey:@"post-status"] firstObject];
				post.isDraft = [status isEqualToString:@"draft"];

				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				self.allPosts = new_posts;
				self.currentPosts = new_posts;
				[self.tableView reloadData];
				[self.progressSpinner stopAnimation:nil];
				[self setupBlogName];
				self.blogNameButton.hidden = NO;
				self.tableView.animator.alphaValue = 1.0;
			});
		}
	}];
}

- (void) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	RFPost* post = [self.currentPosts objectAtIndex:row];
	[self openPost:post];
}

- (void) openPost:(RFPost *)post
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPostingNotification object:self userInfo:@{ kOpenPostingPostKey: post }];
}

- (IBAction) search:(id)sender
{
	NSString* q = [[sender stringValue] lowercaseString];
	if (q.length == 0) {
		self.currentPosts = self.allPosts;
	}
	else {
		NSMutableArray* filtered_posts = [NSMutableArray array];
		for (RFPost* post in self.allPosts) {
			if ([[post.title lowercaseString] containsString:q] || [[post.text lowercaseString] containsString:q]) {
				[filtered_posts addObject:post];
			}
		}
		
		self.currentPosts = filtered_posts;
	}
	
	[self.tableView reloadData];
}

- (IBAction) blogNameClicked:(id)sender
{
	[self showBlogsMenu];
}

- (void) showBlogsMenu
{
	if (self.blogsMenuPopover) {
		[self hideBlogsMenu];
	}
	else {
		if (![RFSettings boolForKey:kExternalBlogIsPreferred]) {
			RFBlogsController* blogs_controller = [[RFBlogsController alloc] init];
			
			self.blogsMenuPopover = [[NSPopover alloc] init];
			self.blogsMenuPopover.contentViewController = blogs_controller;
			self.blogsMenuPopover.behavior = NSPopoverBehaviorTransient;
			self.blogsMenuPopover.delegate = self;

			NSRect r = self.blogNameButton.bounds;
			[self.blogsMenuPopover showRelativeToRect:r ofView:self.blogNameButton preferredEdge:NSRectEdgeMaxY];
		}
	}
}

- (void) hideBlogsMenu
{
	if (self.blogsMenuPopover) {
		[self.blogsMenuPopover performClose:nil];
		self.blogsMenuPopover = nil;
	}
}

- (void) popoverDidClose:(NSNotification *)notification
{
	self.blogsMenuPopover = nil;
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self setupBlogName];
	[self hideBlogsMenu];
	[self fetchPosts];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self fetchPosts];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentPosts.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	RFPost* post = [self.currentPosts objectAtIndex:row];

	cell.titleField.stringValue = post.title;
	cell.textField.stringValue = [post summary];
	cell.dateField.stringValue = [post.postedAt description];
	cell.draftField.hidden = !post.isDraft;
	
	if (post.title.length == 0) {
		cell.textTopConstraint.constant = 10;
	}
	else {
		cell.textTopConstraint.constant = 35;
	}

	return cell;
}

@end
