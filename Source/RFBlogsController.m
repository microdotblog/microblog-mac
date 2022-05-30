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
	self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer* timer) {
		// only show progress if download is taking longer than 1 second
		[self.progressSpinner startAnimation:nil];
	}];
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			self.destinations = [response.parsedResponse objectForKey:@"destination"];
			RFDispatchMainAsync (^{
				[self.progressTimer invalidate];
				[self.progressSpinner stopAnimation:nil];
				[self.tableView reloadData];
			});
		}
	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.destinations.count + 1;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFBlogCell* cell = [tableView makeViewWithIdentifier:@"BlogCell" owner:self];

	if (row < self.destinations.count) {
		NSDictionary* destination = [self.destinations objectAtIndex:row];
		cell.nameField.stringValue = destination[@"name"];
	}
	else {
		cell.nameField.stringValue = @"New Microblog...";
	}

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	if (row < self.destinations.count) {
		NSDictionary* destination = [self.destinations objectAtIndex:row];

		[RFSettings setString:destination[@"uid"] forKey:kCurrentDestinationUID];
		[RFSettings setString:destination[@"name"] forKey:kCurrentDestinationName];

		[[NSNotificationCenter defaultCenter] postNotificationName:kUpdatedBlogNotification object:self];
	}
	else {
		NSURL* url = [NSURL URLWithString:@"https://micro.blog/new/site"];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
	
	return YES;
}

@end
