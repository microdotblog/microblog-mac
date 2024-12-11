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
	[self refresh];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"CollectionCell" bundle:nil] forIdentifier:@"CollectionCell"];
	[self.tableView registerForDraggedTypes:@[ NSPasteboardTypeFileURL, NSPasteboardTypeString ]];
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
