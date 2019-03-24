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
#import "RFClient.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "UUDate.h"

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
	[self fetchPosts];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
}

- (void) fetchPosts
{
	self.posts = @[];
	self.blogNameButton.hidden = YES;
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"source" } completion:^(UUHttpResponse* response) {
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
			self.posts = new_posts;
			[self.tableView reloadData];
			[self.progressSpinner stopAnimation:nil];
			[self setupBlogName];
			self.blogNameButton.hidden = NO;
		});
	}];
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

- (IBAction) blogNameClicked:(id)sender
{
	[self showBlogsMenu];
}

- (void) showBlogsMenu
{
}

- (void) hideBlogsMenu
{
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.posts.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	RFPost* post = [self.posts objectAtIndex:row];

	cell.titleField.stringValue = post.title;
	cell.textField.stringValue = post.text;
	cell.dateField.stringValue = [post.postedAt description];
	cell.draftField.hidden = !post.isDraft;

	return cell;
}

@end
