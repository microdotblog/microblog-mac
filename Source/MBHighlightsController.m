//
//  MBHighlightsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightsController.h"

#import "MBHighlight.h"
#import "MBHighlightCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

@implementation MBHighlightsController

- (id) init
{
	self = [super initWithNibName:@"Highlights" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	
	[self fetchHighlights];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"HighlightCell" bundle:nil] forIdentifier:@"HighlightCell"];
//	[self.tableView setTarget:self];
//	[self.tableView setDoubleAction:@selector(openRow:)];
//	self.tableView.alphaValue = 0.0;
}

- (void) fetchHighlights
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/bookmarks/highlights"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_highlights = [NSMutableArray array];
			for (NSDictionary* info in [response.parsedResponse objectForKey:@"items"]) {
				MBHighlight* h = [[MBHighlight alloc] init];
				h.highlightID = [info objectForKey:@"id"];
				h.selectionText = [info objectForKey:@"content_text"];
				h.title = [info objectForKey:@"title"];
				h.url = [info objectForKey:@"url"];
				
				[new_highlights addObject:h];
			}
			
			RFDispatchMainAsync (^{
				self.currentHighlights = new_highlights;
				[self.tableView reloadData];
			});
		}
	}];
}

- (IBAction) back:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentHighlights.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBHighlightCell* cell = [tableView makeViewWithIdentifier:@"HighlightCell" owner:self];

	if (row < self.currentHighlights.count) {
		MBHighlight* h = [self.currentHighlights objectAtIndex:row];
		[cell setupWithHighlight:h];
	}

	return cell;
}

@end
