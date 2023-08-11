//
//  MBAllTagsController.m
//  Micro.blog
//
//  Created by Manton Reece on 8/10/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBAllTagsController.h"

#import "MBTagCell.h"

@implementation MBAllTagsController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"AllTags"];
	if (self) {
		self.currentTags = @[ @"testing" ];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTable];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"TagCell" bundle:nil] forIdentifier:@"TagCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
}

- (IBAction) openRow:(id)sender
{
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentTags.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBTagCell* cell = [tableView makeViewWithIdentifier:@"TagCell" owner:self];

	if (row < self.currentTags.count) {
		NSString* tag = [self.currentTags objectAtIndex:row];
		[cell setupWithName:tag];
	}

	return cell;
}

@end
