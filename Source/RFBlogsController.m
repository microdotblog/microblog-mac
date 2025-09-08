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
#import "RFAccount.h"

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

	// try cached destinations first, refresh in background
	NSArray* cached = [self loadCachedDestinations];
	if (cached.count > 0) {
		self.destinations = cached;
		[self.tableView reloadData];
		[self fetchBlogsShowProgress:NO];
	}
	else {
		[self fetchBlogsShowProgress:YES];
	}
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BlogCell" bundle:nil] forIdentifier:@"BlogCell"];
}

- (NSString *) cachedDestinationsPrefKey
{
	NSString* username = [RFSettings defaultAccount].username;
	return [NSString stringWithFormat:@"%@_%@", username, @"Destinations"];
}

- (NSArray *) loadCachedDestinations
{
	NSArray* cached = [[NSUserDefaults standardUserDefaults] arrayForKey:[self cachedDestinationsPrefKey]];
	return cached;
}

- (void) saveCachedDestinationsFrom:(NSArray *)destinations
{
	NSMutableArray* pruned = [NSMutableArray array];
	for (NSDictionary* d in destinations) {
		NSString* uid = d[@"uid"] ?: @"";
		NSString* name = d[@"name"] ?: @"";
		[pruned addObject:@{
			@"uid": uid,
			@"name": name
		}];
	}
	[[NSUserDefaults standardUserDefaults] setObject:pruned forKey:[self cachedDestinationsPrefKey]];
}

- (void) fetchBlogsShowProgress:(BOOL)showProgress
{
	if (showProgress) {
		self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer* timer) {
			// only show progress if download is taking longer than 1 second
			[self.progressSpinner startAnimation:nil];
		}];
	}
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* destinations = [response.parsedResponse objectForKey:@"destination"];
			[self saveCachedDestinationsFrom:destinations];
			self.destinations = [[NSUserDefaults standardUserDefaults] arrayForKey:[self cachedDestinationsPrefKey]];
			RFDispatchMainAsync (^{
				[self.progressTimer invalidate];
				[self.progressSpinner stopAnimation:nil];
				[self.tableView reloadData];
			});
		}
	}];
}

- (void) fetchBlogs
{
	[self fetchBlogsShowProgress:YES];
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
