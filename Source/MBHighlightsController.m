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
	
	self.currentHighlights = @[ @"hi" ];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"HighlightCell" bundle:nil] forIdentifier:@"HighlightCell"];
//	[self.tableView setTarget:self];
//	[self.tableView setDoubleAction:@selector(openRow:)];
//	self.tableView.alphaValue = 0.0;
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
//		[cell setupWithHighlight:h];
	}

	return cell;
}

@end
