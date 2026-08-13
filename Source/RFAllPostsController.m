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
static NSInteger const kAllPostsSegmentTag = 0;
static NSInteger const kDraftsSegmentTag = 1;
static NSInteger const kScheduledSegmentTag = 2;
static CGFloat const kAllPostsSegmentWidth = 76.0;
static CGFloat const kDraftsSegmentWidth = 68.0;
static CGFloat const kScheduledSegmentWidth = 90.0;
static NSString* const kSegmentStateCacheKey = @"PostsSegmentStateByHostname";
static NSInteger const kSegmentStateDrafts = 1 << 0;
static NSInteger const kSegmentStateScheduled = 1 << 1;

@interface RFAllPostsController ()

@property (assign, nonatomic) BOOL isObservingWindowNotifications;
@property (assign, nonatomic) NSInteger postsRequestID;
@property (assign, nonatomic) BOOL isShowingScheduled;
@property (assign, nonatomic) BOOL hasLoadedPosts;
@property (assign, nonatomic) BOOL hasLoadedDrafts;
@property (assign, nonatomic) BOOL hasCachedSegmentState;
@property (strong, nonatomic) NSArray* scheduledPosts;
@property (strong, nonatomic) NSTimer* scheduledPostsTimer;

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

	BOOL was_showing_scheduled = self.isShowingScheduled;
	[self updateScheduledPosts];
	if (was_showing_scheduled) {
		if (self.isShowingScheduled) {
			self.currentPosts = self.scheduledPosts;
		}
		else {
			self.currentPosts = self.allPosts;
		}
	}
	[self.tableView reloadData];
	[self refreshDestinationsCache];
}

- (void) dealloc
{
	[self.scheduledPostsTimer invalidate];

	if (self.isObservingWindowNotifications) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
}

- (void) viewDidDisappear
{
	[super viewDidDisappear];
	[self.scheduledPostsTimer invalidate];
	self.scheduledPostsTimer = nil;

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
	self.blogNameButton.toolTip = self.blogNameButton.title;

	if ([self.blogNameButton isKindOfClass:[RFHostnameButton class]]) {
		((RFHostnameButton*) self.blogNameButton).showsChevron = [RFBlogsController hasMultipleCachedDestinations];
	}
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(draftDidUpdateNotification:) name:kDraftDidUpdateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(autosavedDraftDidCreateNotification:) name:kAutosavedDraftDidCreateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(autosavedDraftDidUpdateNotification:) name:kAutosavedDraftDidUpdateNotification object:nil];
}

- (void) setupTabs
{
	[self.segmentedControl setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
	[self loadCachedSegmentState];
}

- (void) updateSegmentedControlVisibility
{
	BOOL has_refreshed_segment_state = self.hasLoadedPosts || self.hasLoadedDrafts;
	BOOL has_segment_state = self.hasCachedSegmentState || has_refreshed_segment_state;
	self.segmentedControl.hidden = self.isShowingPages || !has_segment_state || (self.segmentedControl.segmentCount < 2);
}

- (void) disableTabs
{
	self.segmentedControl.enabled = NO;
	[self.segmentedControl setSelectedSegment:0];
	self.isShowingDrafts = NO;
	self.isShowingScheduled = NO;
}

- (void) updateSegments
{
	if (self.isShowingPages) {
		return;
	}

	BOOL has_drafts = self.hasLoadedDrafts ? (self.draftPosts.count > 0) : [self hasSegmentWithTag:kDraftsSegmentTag];
	BOOL has_scheduled_posts = self.hasLoadedPosts ? (self.scheduledPosts.count > 0) : [self hasSegmentWithTag:kScheduledSegmentTag];
	[self applySegmentsShowingDrafts:has_drafts scheduled:has_scheduled_posts];
	[self cacheSegmentStateShowingDrafts:has_drafts scheduled:has_scheduled_posts];
	[self updateSegmentedControlVisibility];
}

- (BOOL) hasSegmentWithTag:(NSInteger)tag
{
	for (NSInteger i = 0; i < self.segmentedControl.segmentCount; i++) {
		if ([self.segmentedControl tagForSegment:i] == tag) {
			return YES;
		}
	}

	return NO;
}

- (void) applySegmentsShowingDrafts:(BOOL)hasDrafts scheduled:(BOOL)hasScheduled
{
	NSInteger selected_tag = kAllPostsSegmentTag;
	if (self.isShowingDrafts) {
		selected_tag = kDraftsSegmentTag;
	}
	else if (self.isShowingScheduled) {
		selected_tag = kScheduledSegmentTag;
	}

	NSInteger segment_count = 1;
	if (hasDrafts) {
		segment_count++;
	}
	if (hasScheduled) {
		segment_count++;
	}
	self.segmentedControl.segmentCount = segment_count;

	NSInteger segment_index = 0;
	NSInteger selected_index = 0;
	[self.segmentedControl setLabel:@"All Posts" forSegment:segment_index];
	[self.segmentedControl setTag:kAllPostsSegmentTag forSegment:segment_index];
	[self.segmentedControl setWidth:kAllPostsSegmentWidth forSegment:segment_index];

	if (hasDrafts) {
		segment_index++;
		[self.segmentedControl setLabel:@"Drafts" forSegment:segment_index];
		[self.segmentedControl setTag:kDraftsSegmentTag forSegment:segment_index];
		[self.segmentedControl setWidth:kDraftsSegmentWidth forSegment:segment_index];
		if (selected_tag == kDraftsSegmentTag) {
			selected_index = segment_index;
		}
	}
	else if (selected_tag == kDraftsSegmentTag) {
		self.isShowingDrafts = NO;
	}

	if (hasScheduled) {
		segment_index++;
		[self.segmentedControl setLabel:@"Scheduled" forSegment:segment_index];
		[self.segmentedControl setTag:kScheduledSegmentTag forSegment:segment_index];
		[self.segmentedControl setWidth:kScheduledSegmentWidth forSegment:segment_index];
		if (selected_tag == kScheduledSegmentTag) {
			selected_index = segment_index;
		}
	}
	else if (selected_tag == kScheduledSegmentTag) {
		self.isShowingScheduled = NO;
	}

	[self.segmentedControl setSelectedSegment:selected_index];
}

- (NSString *) currentBlogHostname
{
	NSString* hostname = [RFSettings stringForKey:kCurrentDestinationName];
	if (hostname.length == 0) {
		hostname = [RFSettings stringForKey:kAccountDefaultSite];
	}

	return hostname.lowercaseString ?: @"";
}

- (void) loadCachedSegmentState
{
	self.hasCachedSegmentState = NO;
	if (self.isShowingPages) {
		[self applySegmentsShowingDrafts:NO scheduled:NO];
		[self updateSegmentedControlVisibility];
		return;
	}

	NSString* hostname = [self currentBlogHostname];
	NSDictionary* cached_states = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSegmentStateCacheKey];
	NSNumber* state_number = [cached_states objectForKey:hostname];
	if (hostname.length > 0 && [state_number isKindOfClass:[NSNumber class]]) {
		NSInteger state = state_number.integerValue;
		BOOL has_drafts = ((state & kSegmentStateDrafts) != 0);
		BOOL has_scheduled_posts = ((state & kSegmentStateScheduled) != 0);
		self.hasCachedSegmentState = YES;
		[self applySegmentsShowingDrafts:has_drafts scheduled:has_scheduled_posts];
	}
	else {
		[self applySegmentsShowingDrafts:NO scheduled:NO];
	}

	[self updateSegmentedControlVisibility];
}

- (void) cacheSegmentStateShowingDrafts:(BOOL)hasDrafts scheduled:(BOOL)hasScheduled
{
	NSString* hostname = [self currentBlogHostname];
	if (hostname.length == 0) {
		return;
	}

	NSInteger state = 0;
	if (hasDrafts) {
		state |= kSegmentStateDrafts;
	}
	if (hasScheduled) {
		state |= kSegmentStateScheduled;
	}

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary* cached_states = [[defaults dictionaryForKey:kSegmentStateCacheKey] mutableCopy];
	if (cached_states == nil) {
		cached_states = [NSMutableDictionary dictionary];
	}
	[cached_states setObject:@(state) forKey:hostname];
	[defaults setObject:cached_states forKey:kSegmentStateCacheKey];
	self.hasCachedSegmentState = YES;
}

- (void) updateScheduledPosts
{
	NSDate* now = [NSDate date];
	NSMutableArray* scheduled_posts = [NSMutableArray array];
	NSDate* next_post_date = nil;
	for (RFPost* post in self.allPosts) {
		if ((post.postedAt != nil) && ([post.postedAt compare:now] == NSOrderedDescending)) {
			[scheduled_posts addObject:post];
			if ((next_post_date == nil) || ([post.postedAt compare:next_post_date] == NSOrderedAscending)) {
				next_post_date = post.postedAt;
			}
		}
	}

	self.scheduledPosts = scheduled_posts;
	[self updateSegments];
	[self scheduleScheduledPostsUpdateForDate:next_post_date];
}

- (void) scheduleScheduledPostsUpdateForDate:(NSDate *)date
{
	[self.scheduledPostsTimer invalidate];
	self.scheduledPostsTimer = nil;

	if ((date == nil) || (self.view.window == nil)) {
		return;
	}

	NSTimeInterval interval = MAX([date timeIntervalSinceNow] + 0.1, 0.1);
	self.scheduledPostsTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(scheduledPostsTimerFired:) userInfo:nil repeats:NO];
	[[NSRunLoop mainRunLoop] addTimer:self.scheduledPostsTimer forMode:NSRunLoopCommonModes];
}

- (void) scheduledPostsTimerFired:(NSTimer *)timer
{
	self.scheduledPostsTimer = nil;
	BOOL was_showing_scheduled = self.isShowingScheduled;
	[self updateScheduledPosts];

	if (was_showing_scheduled) {
		if (self.isShowingScheduled) {
			self.currentPosts = self.scheduledPosts;
		}
		else {
			self.currentPosts = self.allPosts;
		}
	}

	[self.tableView reloadData];
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) refreshPosts
{
	if (self.isShowingDrafts) {
		[self fetchDrafts];
	}
	else {
		[self fetchPosts];
	}
}

- (void) fetchPosts
{
	self.hasLoadedPosts = NO;
	[self updateSegmentedControlVisibility];
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

				BOOL will_fetch_more = fetchMore && (new_posts.count == limit);
				BOOL was_showing_scheduled = self.isShowingScheduled;
				if (search.length == 0) {
					self.allPosts = posts_to_show;
					self.hasLoadedPosts = YES;
					[self updateScheduledPosts];
					[self updateSegmentedControlVisibility];
				}

				NSString* current_search = self.searchField.stringValue ?: @"";
				if (self.isShowingDrafts || ![current_search isEqualToString:search]) {
					return;
				}

				BOOL is_appending_posts = (existingPosts.count > 0);
				NSInteger existing_count = self.currentPosts.count;
				if (self.isShowingScheduled) {
					self.currentPosts = self.scheduledPosts;
				}
				else {
					self.currentPosts = posts_to_show;
				}

				if (self.isShowingScheduled || (was_showing_scheduled && !self.isShowingScheduled)) {
					[self.tableView reloadData];
				}
				else if (is_appending_posts && new_posts.count > 0) {
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

				if (will_fetch_more) {
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
	self.hasLoadedDrafts = NO;
	[self updateSegmentedControlVisibility];
	
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
				BOOL was_showing_drafts = self.isShowingDrafts;
				self.draftPosts = new_posts;
				self.isDownloadingDrafts = NO;
				self.hasLoadedDrafts = YES;
				[self updateSegments];
				[self updateSegmentedControlVisibility];
				if (was_showing_drafts) {
					if (self.isShowingDrafts) {
						self.currentPosts = self.draftPosts;
					}
					else {
						self.currentPosts = self.allPosts;
					}
					[self.tableView reloadData];
				}
			});
		}
	}];
}

- (void) fetchDraftsQuietlyForPostID:(NSNumber *)postID
{
	if (postID.integerValue <= 0) {
		return;
	}

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
		if (![response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			return;
		}

		NSMutableArray* new_posts = [NSMutableArray array];
		NSArray* items = [response.parsedResponse objectForKey:@"items"];
		for (NSDictionary* item in items) {
			NSDictionary* props = [item objectForKey:@"properties"];
			RFPost* post = [[RFPost alloc] initFromProperties:props];
			post.channel = channel;
			[new_posts addObject:post];
		}

		RFDispatchMainAsync(^{
			NSString* current_destination_uid = [RFSettings stringForKey:kCurrentDestinationUID] ?: @"";
			if (![current_destination_uid isEqualToString:destination_uid]) {
				return;
			}

			RFPost* updated_post = nil;
			for (RFPost* post in new_posts) {
				if (post.postID.integerValue == postID.integerValue) {
					updated_post = post;
					break;
				}
			}

			self.draftPosts = new_posts;
			self.hasLoadedDrafts = YES;

			if (!self.isShowingDrafts || (updated_post == nil)) {
				return;
			}

			NSInteger row = NSNotFound;
			for (NSInteger i = 0; i < self.currentPosts.count; i++) {
				RFPost* post = [self.currentPosts objectAtIndex:i];
				if (post.postID.integerValue == postID.integerValue) {
					row = i;
					break;
				}
			}

			if ((row != NSNotFound) && (row < self.tableView.numberOfRows)) {
				NSMutableArray* current_posts = [self.currentPosts mutableCopy];
				[current_posts replaceObjectAtIndex:row withObject:updated_post];
				self.currentPosts = current_posts;

				RFPostCell* cell = (RFPostCell*) [self.tableView rowViewAtRow:row makeIfNecessary:YES];
				if ([cell isKindOfClass:[RFPostCell class]]) {
					NSString* search = self.searchField.stringValue ?: @"";
					[cell setupWithPost:updated_post skipPhotos:NO search:search];
					[cell layoutSubtreeIfNeeded];
					[cell setNeedsDisplay:YES];
				}
			}
		});
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
	self.isShowingDrafts = NO;
	self.isShowingScheduled = NO;
	self.hasLoadedPosts = NO;
	self.hasLoadedDrafts = NO;
	self.draftPosts = nil;
	self.scheduledPosts = @[];
	[self loadCachedSegmentState];
	
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

- (void) autosavedDraftDidCreateNotification:(NSNotification *)notification
{
	if (self.isShowingPages) {
		return;
	}

	[self fetchDrafts];
}

- (void) autosavedDraftDidUpdateNotification:(NSNotification *)notification
{
	if (self.isShowingPages) {
		return;
	}

	NSNumber* post_id = notification.userInfo[kAutosavedDraftPostIDKey];
	[self fetchDraftsQuietlyForPostID:post_id];
}

- (IBAction) segmentChanged:(NSSegmentedControl *)sender
{
	NSInteger selected_tag = [sender tagForSegment:sender.selectedSegment];
	self.isShowingDrafts = (selected_tag == kDraftsSegmentTag);
	self.isShowingScheduled = (selected_tag == kScheduledSegmentTag);
	
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
	else if (self.isShowingScheduled) {
		[self updateScheduledPosts];
		if (self.isShowingScheduled) {
			self.currentPosts = self.scheduledPosts;
		}
		else {
			self.currentPosts = self.allPosts;
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
