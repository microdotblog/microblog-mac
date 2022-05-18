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
	
	[self fetchReplies];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
	[self.tableView setTarget:self];
//	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;
}

- (void) fetchReplies
{
	self.allReplies = @[];
	[self.progressSpinner startAnimation:nil];
	self.tableView.animator.alphaValue = 0.0;

	NSDictionary* args;
	
	args = @{
		@"count": @50
	};

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
				post.channel = @"";
				post.categories = @[];
				
				[new_posts addObject:post];
			}
			
			RFDispatchMainAsync (^{
				self.allReplies = new_posts;
				[self.tableView reloadData];
				[self.progressSpinner stopAnimation:nil];
				self.tableView.animator.alphaValue = 1.0;
			});
		}
	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.allReplies.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	if (row < self.allReplies.count) {
		RFPost* post = [self.allReplies objectAtIndex:row];
		[cell setupWithPost:post];
	}

	return cell;
}

@end
