//
//  RFBlogsController.m
//  Snippets
//
//  Created by Manton Reece on 3/21/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFBlogsController.h"

#import "RFBlogCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "RFSettings.h"

@implementation RFBlogsController

- (instancetype) init
{
	self = [super initWithNibName:@"Blogs" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self fetchBlogs];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BlogCell" bundle:nil] forIdentifier:@"BlogCell"];
}

- (void) fetchBlogs
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
		self.destinations = [response.parsedResponse objectForKey:@"destination"];
		RFDispatchMainAsync (^{
			[self.tableView reloadData];
		});
	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.destinations.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFBlogCell* cell = [tableView makeViewWithIdentifier:@"BlogCell" owner:self];

	NSDictionary* destination = [self.destinations objectAtIndex:row];
	cell.nameField.stringValue = destination[@"name"];

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	NSDictionary* destination = [self.destinations objectAtIndex:row];

	[RFSettings setString:destination[@"uid"] forKey:kCurrentDestinationUID];
	[RFSettings setString:destination[@"name"] forKey:kCurrentDestinationName];

	[[NSNotificationCenter defaultCenter] postNotificationName:kUpdatedBlogNotification object:self];

	return YES;
}

@end
