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
#import "MBMenus.h"
#import "UUDate.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"

static NSInteger const kRecentPostsInitialLimit = 15;
static NSInteger const kRecentPostsBackgroundLimit = 100;

@interface RFAllPostsController ()

@property (assign, nonatomic) BOOL isObservingWindowNotifications;
@property (assign, nonatomic) NSInteger postsRequestID;

@end

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
	[self fetchDrafts];
}

- (void) viewDidAppear
{
	[super viewDidAppear];

	if (!self.isObservingWindowNotifications && self.view.window != nil) {
		self.isObservingWindowNotifications = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.view.window];
	}

	[self refreshDestinationsCache];
}

- (void) dealloc
{
	if (self.isObservingWindowNotifications) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
}

- (void) viewDidDisappear
{
	[super viewDidDisappear];

	if (self.isObservingWindowNotifications) {
		self.isObservingWindowNotifications = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
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

	if ([self.blogNameButton isKindOfClass:[RFHostnameButton class]]) {
		((RFHostnameButton*) self.blogNameButton).showsChevron = [RFBlogsController hasMultipleCachedDestinations];
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
	self.postsRequestID++;
	NSInteger request_id = self.postsRequestID;

	self.currentPosts = @[];
	self.blogNameButton.hidden = YES;
	self.tableView.animator.alphaValue = 0.0;

	if (search.length == 0) {
		[self fetchPostsForSearch:search limit:kRecentPostsInitialLimit offset:0 existingPosts:nil requestID:request_id fetchMore:YES];
	}
	else {
		[self fetchPostsForSearch:search limit:0 offset:0 existingPosts:nil requestID:request_id fetchMore:NO];
	}
}

- (void) fetchPostsForSearch:(NSString *)search limit:(NSInteger)limit offset:(NSInteger)offset existingPosts:(NSArray *)existingPosts requestID:(NSInteger)requestID fetchMore:(BOOL)fetchMore
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSMutableDictionary* args;
	NSString* channel;
	
	if (self.isShowingPages) {
		channel = @"pages";
	}
	else {
		channel = @"default";
	}
	
	args = [@{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"mp-channel": channel,
		@"filter": search
	} mutableCopy];
	
	if (limit > 0) {
		[args setObject:@(limit) forKey:@"limit"];
		[args setObject:@(offset) forKey:@"offset"];
	}

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* props = [item objectForKey:@"properties"];
				RFPost* post = [[RFPost alloc] initFromProperties:props];
				post.channel = channel;
				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				if (requestID != self.postsRequestID) {
					return;
				}

				NSArray* posts_to_show = new_posts;
				NSString* selected_url = nil;
				NSInteger selected_row = self.tableView.selectedRow;
				if ((existingPosts.count > 0) && (selected_row >= 0) && (selected_row < self.currentPosts.count)) {
					RFPost* selected_post = [self.currentPosts objectAtIndex:selected_row];
					selected_url = selected_post.url;
				}

				if (existingPosts.count > 0) {
					NSMutableArray* merged_posts = [existingPosts mutableCopy];
					[merged_posts addObjectsFromArray:new_posts];
					posts_to_show = merged_posts;
				}

				if (search.length == 0) {
					self.allPosts = posts_to_show;
				}

				NSString* current_search = self.searchField.stringValue ?: @"";
				if (self.isShowingDrafts || ![current_search isEqualToString:search]) {
					return;
				}

				BOOL is_appending_posts = (existingPosts.count > 0);
				NSInteger existing_count = self.currentPosts.count;
				self.currentPosts = posts_to_show;

				if (is_appending_posts && new_posts.count > 0) {
					NSRange range = NSMakeRange(existing_count, new_posts.count);
					NSIndexSet* row_indexes = [NSIndexSet indexSetWithIndexesInRange:range];
					[self.tableView insertRowsAtIndexes:row_indexes withAnimation:NSTableViewAnimationEffectNone];
				}
				else if (!is_appending_posts) {
					[self.tableView reloadData];
				}
				[self restoreSelectionForPostURL:selected_url];

				[self setupBlogName];
				[self stopLoadingSidebarRow];

				[self.progressSpinner stopAnimation:nil];
				self.blogNameButton.hidden = NO;
				self.tableView.animator.alphaValue = 1.0;

				if (fetchMore && new_posts.count == limit) {
					NSInteger next_offset = offset + limit;
					BOOL should_fetch_more = (offset == 0);
					[self fetchPostsForSearch:search limit:kRecentPostsBackgroundLimit offset:next_offset existingPosts:posts_to_show requestID:requestID fetchMore:should_fetch_more];
				}
			});
		}
	}];
}

- (void) restoreSelectionForPostURL:(NSString *)url
{
	if (url.length == 0) {
		return;
	}

	for (NSInteger i = 0; i < self.currentPosts.count; i++) {
		RFPost* post = [self.currentPosts objectAtIndex:i];
		if ([post.url isEqualToString:url]) {
			NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:i];
			[self.tableView selectRowIndexes:index_set byExtendingSelection:NO];
			break;
		}
	}
}

- (void) fetchDrafts
{
	self.isDownloadingDrafts = YES;
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSString* channel = @"default";

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"mp-channel": channel,
		@"post-status": @"draft"
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* props = [item objectForKey:@"properties"];
				RFPost* post = [[RFPost alloc] initFromProperties:props];
				post.channel = channel;
				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				self.draftPosts = new_posts;
				self.isDownloadingDrafts = NO;
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

- (IBAction) copyLinkOrHTML:(id)sender
{
	[self copyLink:sender];
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
			s = [post displaySummary];
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
	self.blogNameButton.hidden = YES;

	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				[self.progressSpinner stopAnimation:nil];
				self.blogNameButton.hidden = NO;
				NSString* msg = response.parsedResponse[@"error_description"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Post" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchPosts];
				[self fetchDrafts];
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

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self refreshDestinationsCache];
}

- (void) refreshDestinationsCache
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	[RFBlogsController fetchDestinationsInBackgroundWithCompletion:^(NSArray* destinations) {
		#pragma unused(destinations)
		[self setupBlogName];
	}];
}

- (void) showBlogsMenu
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	NSMenu* menu = [RFBlogsController blogsMenuWithTarget:[RFBlogsController class] action:@selector(selectDestinationMenuItem:)];
	if (menu.numberOfItems == 0) {
		return;
	}

	NSPoint menu_point = NSMakePoint(0.0, NSMinY(self.blogNameButton.bounds));
	[menu popUpMenuPositioningItem:nil atLocation:menu_point inView:self.blogNameButton];
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	// reset to all posts
	[self.segmentedControl setSelectedSegment:0];
	
	[self setupBlogName];
	
	[self fetchPosts];
	[self fetchDrafts];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self fetchPosts];
	[self fetchDrafts];
}

- (void) draftDidUpdateNotification:(NSNotification *)notification
{
	[self fetchPosts];
	[self fetchDrafts];
}

- (IBAction) segmentChanged:(NSSegmentedControl *)sender
{
	self.isShowingDrafts = (sender.selectedSegment == 1);
	
	if (self.isShowingDrafts) {
		// if still downloading, wait
		if (self.isDownloadingDrafts) {
			RFDispatchSeconds(2.0, ^{
				if (!self.isShowingDrafts) {
					return;
				}
				
				self.currentPosts = self.draftPosts;
				[self.tableView reloadData];
			});
			return;
		}
		else {
			self.currentPosts = self.draftPosts;
		}
	}
	else {
		self.currentPosts = self.allPosts;
	}
	
	[self.tableView reloadData];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(copyLinkOrHTML:)) {
		[item setTitle:@"Copy Link"];
		NSInteger row = self.tableView.selectedRow;
		return (row >= 0);
	}
	
	return YES;
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
		NSString* q = self.searchField.stringValue;
		[cell setupWithPost:post skipPhotos:NO search:q];
	}
	
	return cell;
}

@end
