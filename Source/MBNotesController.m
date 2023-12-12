//
//  MBNotesController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNotesController.h"

#import "MBNote.h"
#import "MBNoteCell.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "UUDate.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"

@implementation MBNotesController

- (id) init
{
	self = [super initWithNibName:@"Notes" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupNotifications];
	
	[self fetchNotes];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"NoteCell" bundle:nil] forIdentifier:@"NoteCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
}

- (void) setupNotifications
{
}

- (void) fetchNotes
{
	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/notes/notebooks/1"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_notes = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBNote* n = [[MBNote alloc] init];
				n.text = [item objectForKey:@"content_text"];
				
				NSString* date_s = [item objectForKey:@"date_published"];
				n.createdAt = [NSDate uuDateFromRfc3339String:date_s];
				
				[new_notes addObject:n];
			}
			
			RFDispatchMainAsync(^{
				self.allNotes = new_notes;
				self.currentNotes = new_notes;
				[self.tableView reloadData];
			});
		}

		[self stopLoadingSidebarRow];
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

#pragma mark -

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
//		RFPost* post = [self.currentPosts objectAtIndex:row];
//		[self openPost:post];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentNotes.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBNoteCell* cell = [tableView makeViewWithIdentifier:@"NoteCell" owner:self];

	if (row < self.currentNotes.count) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		[cell setupWithNote:n];
	}

	return cell;
}

@end
