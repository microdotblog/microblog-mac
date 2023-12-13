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
	
	[self setupSecretKey];
	[self setupTable];
	[self setupNotifications];
	
	[self fetchNotes];
}

- (void) setupSecretKey
{
	NSString* s = [[NSUserDefaults standardUserDefaults] objectForKey:@"NotesSecretKey"];
	self.secretKey = [s substringFromIndex:4];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"NoteCell" bundle:nil] forIdentifier:@"NoteCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startNewNoteNotification:) name:kNewNoteNotification object:nil];
}

- (void) fetchNotes
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/notes/notebooks/1"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_notes = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* mb = [item objectForKey:@"_microblog"];
				
				MBNote* n = [[MBNote alloc] init];
				n.noteID = [item objectForKey:@"id"];
				if ([[mb objectForKey:@"is_encrypted"] boolValue]) {
					n.text = [MBNote decryptText:[item objectForKey:@"content_text"] withKey:self.secretKey];
					if (n.text == nil) {
						// decryption probably failed
						n.text = @"";
					}
				}
				else {
					n.text = [item objectForKey:@"content_text"];
				}
				
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

		RFDispatchMainAsync(^{
			[self stopLoadingSidebarRow];
		});
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
//		MBNote* n = [self.currentNotes objectAtIndex:row];
//		[self openNote:n];
	}
}

- (void) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];

		NSString* s = n.text;
		if (s.length > 20) {
			s = [s substringToIndex:20];
			s = [s stringByAppendingString:@"..."];
		}
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", s];
		sheet.informativeText = @"This note will be deleted from Micro.blog.";
		[sheet addButtonWithTitle:@"Delete"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[self deleteNote:n];
			}
		}];
	}
}

- (void) deleteNote:(MBNote *)note
{
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/%@", note.noteID];

	[self.progressSpinner startAnimation:nil];
	
	[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				[self.progressSpinner stopAnimation:nil];
				NSString* msg = response.parsedResponse[@"error"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Note" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchNotes];
			}
		});
	}];
}

- (void) syncNote:(MBNote *)note
{
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithPath:@"/notes"];
	NSString* s = note.text;
	
	if (note.isEncrypted) {
		s = [MBNote encryptText:s withKey:self.secretKey];
	}
	
	NSDictionary* args;
	
	if (note.noteID == nil) {
		args = @{
			@"text": s,
			@"is_encrypted": @(YES)
		};
	}
	else {
		args = @{
			@"id": note.noteID,
			@"text": s,
			@"is_encrypted": [NSNumber numberWithBool:note.isEncrypted]
		};
	}
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			[self.progressSpinner startAnimation:nil];
		});
	}];
}

- (void) startNewNoteNotification:(NSNotification *)notification
{
	MBNote* n = [[MBNote alloc] init];
	n.text = @"";
	n.isEncrypted = YES;
	n.createdAt = [NSDate date];
	
	NSMutableArray* new_notes = [self.allNotes mutableCopy];
	[new_notes insertObject:n atIndex:0];
	
	self.allNotes = new_notes;
	self.currentNotes = new_notes;
	[self.tableView reloadData];
	
	[self syncNote:n];
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

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		[self.detailTextView setString:n.text];
	}
}

@end
