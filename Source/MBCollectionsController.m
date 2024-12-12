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
#import "MBEditCollectionCell.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "HTMLParser.h"

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
	[self setupNotifications];
	
	[self refresh];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"CollectionCell" bundle:nil] forIdentifier:@"CollectionCell"];
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"EditCollectionCell" bundle:nil] forIdentifier:@"EditCollectionCell"];
	[self.tableView registerForDraggedTypes:@[ NSPasteboardTypeFileURL, NSPasteboardTypeString ]];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCollectionsNotification:) name:kUpdateCollectionsNotification object:nil];
}

#pragma mark -

- (void) updateCollectionsNotification:(NSNotification *)notification
{
	[self refresh];
}

- (void) refresh
{
	[self.tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
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
				NSInteger selected_row = self.tableView.selectedRow;
				self.collections = new_collections;
				[self.tableView reloadData];
				if ((selected_row >= 0) && (selected_row < self.collections.count)) {
					[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selected_row] byExtendingSelection:NO];
				}
				
				[self.progressSpinner stopAnimation:nil];
			});
		}

	}];
}

- (void) addUploadURL:(NSString *)url toCollection:(MBCollection *)collection
{
	[self.progressSpinner startAnimation:nil];
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* info = @{
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid,
		@"action": @"update",
		@"url": collection.url,
		@"add": @{
			@"photo": @[ url ]
		}
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client postWithObject:info completion:^(UUHttpResponse *response) {
		if (![[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSLog(@"Error adding URL: %@", response.rawResponse);
		}
		
		RFDispatchMain(^{
			[self refresh];
		});
	}];
}

- (NSString *) parseURLinHTML:(NSString *)html
{
	NSString* url = nil;
	NSError* error = nil;

	HTMLParser* p = [[HTMLParser alloc] initWithString:html error:&error];
	if (error == nil) {
		HTMLNode* body = [p body];
		HTMLNode* img_tag = [[body findChildTags:@"img"] firstObject];
		url = [img_tag getAttributeNamed:@"src"];
	}
	
	return url;
}

- (void) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		MBCollection* c = [self.collections objectAtIndex:row];
		[[NSNotificationCenter defaultCenter] postNotificationName:kShowCollectionNotification object:self userInfo:@{
			kCollectionKey: c
		}];
	}
}

- (IBAction) newCollection:(id)sender
{
	// bail if we've already started a new collection
	for (MBCollection* c in self.collections) {
		if (c.url == nil) {
			return;
		}
	}
	
	// make a new selection to prompt for name
	MBCollection* c = [[MBCollection alloc] init];
	c.name = @"";
	
	NSMutableArray* new_collections = [self.collections mutableCopy];
	[new_collections insertObject:c atIndex:0];
	
	self.collections = new_collections;

	// clear selection and reload
	[self.tableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[self.tableView reloadData];
	
	// select new item at top
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	RFDispatchSeconds(0.5, ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kEditCollectionNotification object:self];
	});
}

- (IBAction) deleteCollection:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	MBCollection* c = self.collections[row];
	
	[self.progressSpinner startAnimation:nil];
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* info = @{
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid,
		@"action": @"delete",
		@"url": c.url
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client postWithObject:info completion:^(UUHttpResponse *response) {
		if (![[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSLog(@"Error adding URL: %@", response.rawResponse);
		}
		
		RFDispatchMain(^{
			[self refresh];
		});
	}];
}

- (IBAction) copyShortcode:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	MBCollection* c = self.collections[row];
	
	NSString* s = [NSString stringWithFormat:@"{{< collection %@ >}}", c.name];
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:s forType:NSPasteboardTypeString];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.collections.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	NSTableRowView* result = nil;
	
	if (row < self.collections.count) {
		MBCollection* c = [self.collections objectAtIndex:row];

		if (c.url == nil) {
			MBEditCollectionCell* cell = [tableView makeViewWithIdentifier:@"EditCollectionCell" owner:self];
			result = cell;
		}
		else {
			MBCollectionCell* cell = [tableView makeViewWithIdentifier:@"CollectionCell" owner:self];
			[cell setupWithCollection:c];
			result = cell;
		}
	}

	return result;
}

- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
	if (dropOperation == NSTableViewDropOn) {
		if ([info.draggingPasteboard.types containsObject:NSPasteboardTypeString]) {
			tableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleRegular;
			return NSDragOperationCopy;
		}
		else if ([info.draggingPasteboard.types containsObject:NSPasteboardTypeFileURL]) {
//			tableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleRegular;
//			return NSDragOperationCopy;
		}
	}

	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
	NSPasteboard* pb = info.draggingPasteboard;
	MBCollection* c = [self.collections objectAtIndex:row];

	if ([pb.types containsObject:NSPasteboardTypeString]) {
		NSString* s = [pb stringForType:NSPasteboardTypeString];
		if ([s containsString:@"<img"]) {
			NSString* url = [self parseURLinHTML:s];
			if (url) {
				[self addUploadURL:url toCollection:c];
				return YES;
			}
		}
	}
	else {
		NSArray* file_urls = [pb readObjectsForClasses:@[ [NSURL class] ] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
		if (file_urls.count > 0) {
			for (NSURL* url in file_urls) {
				NSLog(@"Dropped file: %@", url.path);
			}
			
			[self.tableView reloadData];
			return YES;
		}
	}
	
	return NO;
}

@end
