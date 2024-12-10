//
//  MBCollectionsController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/10/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBCollectionsController.h"

#import "MBCollection.h"
#import "MBCollectionCell.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "RFSettings.h"

@implementation MBCollectionsController

- (id) init
{
	self = [super initWithWindowNibName:@"Collections" owner:self];
	if (self) {
		self.collections = @[];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTable];
	[self refresh];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"CollectionCell" bundle:nil] forIdentifier:@"CollectionCell"];
}

- (void) refresh
{
	[self fetchCollections];
}

- (void) fetchCollections
{
	[self.progressSpinner startAnimation:nil];
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"q": @"source",
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSArray* items = [[response parsedResponse] objectForKey:@"items"];
			NSMutableArray* new_collections = [NSMutableArray array];
			for (NSDictionary* info in items) {
				NSDictionary* props = [info objectForKey:@"properties"];
				MBCollection* c = [[MBCollection alloc] init];
				c.name = [[props objectForKey:@"name"] firstObject];
				c.url = [[props objectForKey:@"url"] firstObject];
				c.uploadsCount = [props objectForKey:@"microblog-uploads-count"];
				[new_collections addObject:c];
			}
			
			RFDispatchMain(^{
				self.collections = new_collections;
				[self.tableView reloadData];
				[self.progressSpinner stopAnimation:nil];
			});
		}

	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.collections.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBCollectionCell* cell = [tableView makeViewWithIdentifier:@"CollectionCell" owner:self];

	if (row < self.collections.count) {
		MBCollection* c = [self.collections objectAtIndex:row];
		[cell setupWithCollection:c];
	}

	return cell;
}

@end
