//
//  RFRepliesController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFRepliesController.h"

#import "RFPostCell.h"
#import "RFPost.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "UUDate.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"
#import "MBMenus.h"

@implementation RFRepliesController

- (id) init
{
	self = [super initWithNibName:@"Replies" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupBrowser];
	[self setupNotifications];
	
	[self fetchReplies];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(replyDidUpdateNotification:) name:kReplyDidUpdateNotification object:nil];
}

#pragma mark -

- (void) fetchReplies
{
	self.allReplies = @[];
	[self fetchRepliesWithSearch:@""];
}

- (void) fetchRepliesWithSearch:(NSString *)search
{
	self.currentReplies = @[];
	self.tableView.animator.alphaValue = 0.0;

	NSDictionary* args;
	if (search.length > 0) {
		args = @{
			@"count": @50,
			@"q": search
		};
	}
	else {
		args = @{
			@"count": @50
		};
	}

	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/replies"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFPost* post = [[RFPost alloc] init];
				post.postID = [item objectForKey:@"id"];
				post.title = @"";
				post.text = [item objectForKey:@"content_text"];
				post.url = [item objectForKey:@"url"];

				NSString* date_s = [item objectForKey:@"date_published"];
				post.postedAt = [NSDate uuDateFromRfc3339String:date_s];

				post.isDraft = NO;
				post.isReply = YES;
				post.channel = @"";
				post.categories = @[];
				
				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				self.currentReplies = new_posts;
				if (search.length == 0) {
					self.allReplies = self.currentReplies;
				}
				[self.tableView reloadData];
				self.tableView.animator.alphaValue = 1.0;
				[self stopLoadingSidebarRow];
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		RFPost* post = [self.currentReplies objectAtIndex:row];
		[self openPost:post];
	}
}

- (IBAction) openInBrowser:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentReplies objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:post.url];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentReplies objectAtIndex:row];
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

- (IBAction) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		RFPost* post = [self.currentReplies objectAtIndex:row];
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
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				[self.progressSpinner stopAnimation:nil];
				NSString* msg = response.parsedResponse[@"error_description"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Post" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchReplies];
			}
		});
	}];
}

- (void) replyDidUpdateNotification:(NSNotification *)notification
{
	[self fetchReplies];
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length > 2) {
		[self.progressSpinner startAnimation:nil];
		[self fetchRepliesWithSearch:s];
	}
	else {
		self.currentReplies = self.allReplies;
		[self.tableView reloadData];
	}
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
	return self.currentReplies.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	if (row < self.currentReplies.count) {
		RFPost* post = [self.currentReplies objectAtIndex:row];
		NSString* q = self.searchField.stringValue;
		[cell setupWithPost:post skipPhotos:NO search:q];
	}

	return cell;
}

@end
