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
#import "NSAlert+Extras.h"

@implementation RFAllPostsController

- (id) initShowingPages:(BOOL)isShowingPages
{
	self = [super initWithNibName:@"AllPosts" bundle:nil];
	if (self) {
		self.isShowingPages = isShowingPages;
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupBlogName];
	[self setupNotifications];
	[self setupBrowser];
	[self setupTabs];
	
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(draftDidUpdateNotification:) name:kDraftDidUpdateNotification object:nil];
}

- (void) setupTabs
{
	self.segmentedControl.hidden = self.isShowingPages;
}

- (void) disableTabs
{
	self.segmentedControl.enabled = NO;
	[self.segmentedControl setSelectedSegment:0];
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) fetchPosts
{
	[self fetchPostsForSearch:@""];
}

- (void) fetchPostsForSearch:(NSString *)search
{
	self.currentPosts = @[];
	self.blogNameButton.hidden = YES;
	self.tableView.animator.alphaValue = 0.0;

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

    NSDictionary* args;
	NSString* channel;
	
	if (self.isShowingPages) {
		channel = @"pages";
	}
	else {
		channel = @"default";
	}
    
	args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"mp-channel": channel,
		@"filter": search
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
				post.url = [[props objectForKey:@"url"] firstObject];

				NSString* date_s = [[props objectForKey:@"published"] firstObject];
				post.postedAt = [NSDate uuDateFromRfc3339String:date_s];

				NSString* status = [[props objectForKey:@"post-status"] firstObject];
				post.isDraft = [status isEqualToString:@"draft"];
				post.channel = channel;
				
				post.categories = @[];
				if ([[props objectForKey:@"category"] count] > 0) {
					post.categories = [props objectForKey:@"category"];
				}

				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				if (search.length == 0) {
					self.allPosts = new_posts;
				}
				self.currentPosts = new_posts;
				[self.tableView reloadData];
				[self setupBlogName];
				[self stopLoadingSidebarRow];
				self.blogNameButton.hidden = NO;
				self.tableView.animator.alphaValue = 1.0;

				// would be nice to restore selection, but might be a different blog, etc.
				// do this later
//				NSIndexSet* selection = [self.tableView selectedRowIndexes];
//				if (selection.count > 0) {
//					[self.tableView selectRowIndexes:selection byExtendingSelection:NO];
//				}
			});
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

#pragma mark -

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		RFPost* post = [self.currentPosts objectAtIndex:row];
		[self openPost:post];
	}
}

- (IBAction) openInBrowser:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentPosts objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:post.url];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentPosts objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:post.url forType:NSPasteboardTypeString];
	}
}

- (void) openPost:(RFPost *)post
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPostingNotification object:self userInfo:@{ kOpenPostingPostKey: post }];
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (void) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentPosts objectAtIndex:row];
		NSString* s = post.title;
		if (s.length == 0) {
			s = [post summary];
			if (s.length > 20) {
				s = [s substringToIndex:20];
				s = [s stringByAppendingString:@"..."];
			}
		}
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", s];
		sheet.informativeText = @"This post will be removed from your blog and the Micro.blog timeline.";
		[sheet addButtonWithTitle:@"Delete"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[self deletePost:post];
			}
		}];
	}
}

- (void) deletePost:(RFPost *)post
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"action": @"delete",
		@"mp-destination": destination_uid,
		@"url": post.url,
	};

	[self.progressSpinner startAnimation:nil];
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				[self.progressSpinner stopAnimation:nil];
				NSString* msg = response.parsedResponse[@"error_description"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Post" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchPosts];
			}
		});
	}];
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length == 0) {
		self.currentPosts = self.allPosts;
		[self.tableView reloadData];
		self.segmentedControl.enabled = YES;
	}
	else if (s.length < 4) {
		// for short queries, just filter local recent posts
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
		[self disableTabs];
	}
	else {
		[self fetchPostsForSearch:[sender stringValue]];
		[self disableTabs];
	}
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

- (void) draftDidUpdateNotification:(NSNotification *)notification
{
	[self fetchPosts];
}

- (IBAction) segmentChanged:(NSSegmentedControl *)sender
{
	self.isShowingDrafts = (sender.selectedSegment == 1);
	
	if (self.isShowingDrafts) {
		NSMutableArray* only_drafts = [NSMutableArray array];
		for (RFPost* post in self.allPosts) {
			if (post.isDraft) {
				[only_drafts addObject:post];
			}
		}
		self.currentPosts = only_drafts;
	}
	else {
		self.currentPosts = self.allPosts;
	}
	
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentPosts.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	if (row < self.currentPosts.count) {
		RFPost* post = [self.currentPosts objectAtIndex:row];
		[cell setupWithPost:post];
	}

	return cell;
}

@end
