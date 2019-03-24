//
//  RFAllPostsController.m
//  Snippets
//
//  Created by Manton Reece on 3/23/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFAllPostsController.h"

#import "RFPostCell.h"
#import "RFClient.h"

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
	[self fetchPosts];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
}

- (void) fetchPosts
{
	self.posts = @[ @"Hello", @"World" ];
	[self.tableView reloadData];

//	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
//	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
//		self.destinations = [response.parsedResponse objectForKey:@"destination"];
//		RFDispatchMainAsync (^{
//			[self.tableView reloadData];
//		});
//	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.posts.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	cell.titleField.stringValue = @"Title";
	cell.textField.stringValue = @"Testing";

	return cell;
}

@end
