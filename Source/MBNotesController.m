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
#import "MBNotesKeyController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "UUDate.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"
#import "SAMKeychain.h"

@implementation MBNotesController

- (id) init
{
	self = [super initWithNibName:@"Notes" bundle:nil];
	if (self) {
		self.editedNotes = [NSMutableSet set];
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupSecretKey];
	[self setupTable];
	[self setupNotifications];
	[self setupTimer];
	[self setupDetail];
	
	[self fetchNotes];
}

- (void) setupSecretKey
{
	NSString* s = [SAMKeychain passwordForService:@"Micro.blog Notes" account:@""];
	if (s) {
		self.secretKey = [s substringFromIndex:4];
	}
	else {
		// a bit hacky
		RFDispatchSeconds(0.5, ^{
			self.notesKeyController = [[MBNotesKeyController alloc] init];
			[self.view.window beginSheet:self.notesKeyController.window completionHandler:^(NSModalResponse returnCode) {
				self.notesKeyController = nil;
			}];
		});
	}
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesKeyUpdatedNotification:) name:kNotesKeyUpdatedNotification object:nil];
}

- (void) setupTimer
{
	[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(syncFromTimer:) userInfo:nil repeats:YES];
}

- (void) setupDetail
{
	[self.detailTextView setFont:[NSFont systemFontOfSize:14]];
}

#pragma mark -

- (void) fetchNotes
{
	[self fetchNotesWithCompletion:nil];
}

- (void) fetchNotesWithCompletion:(void (^)(void))handler
{
	if (self.secretKey == nil) {
		return;
	}

	// remember selection if there is one
	NSNumber* selected_id = nil;
	NSInteger selected_row = [self.tableView selectedRow];
	if (selected_row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:selected_row];
		selected_id = n.noteID;
	}
	
	RFClient* notebooks_client = [[RFClient alloc] initWithPath:@"/notes/notebooks"];
	[notebooks_client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			NSDictionary* item = [items firstObject];
			NSNumber* notebook_id = [item objectForKey:@"id"];

			RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/notebooks/%@", notebook_id];
			[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
					NSMutableArray* new_notes = [NSMutableArray array];
					
					NSArray* items = [response.parsedResponse objectForKey:@"items"];
					for (NSDictionary* item in items) {
						NSDictionary* mb = [item objectForKey:@"_microblog"];
						
						MBNote* n = [[MBNote alloc] init];
						
						n.noteID = [item objectForKey:@"id"];
						n.isEncrypted = [[mb objectForKey:@"is_encrypted"] boolValue];
						
						if (n.isEncrypted) {
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
						if (handler) {
							handler();
						}
						
						// restore selection
						if (selected_id) {
							for (NSInteger i = 0; i < self.currentNotes.count; i++) {
								MBNote* n = [self.currentNotes objectAtIndex:i];
								if ([n.noteID isEqualToNumber:selected_id]) {
									NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:i];
									[self.tableView selectRowIndexes:index_set byExtendingSelection:NO];
									break;
								}
							}
						}
					});
				}

				RFDispatchMainAsync(^{
					[self.progressSpinner stopAnimation:nil];
					[self stopLoadingSidebarRow];
				});
			}];
		}
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
			
			self.detailTextView.string = @"";
		});
	}];
}

- (void) syncNote:(MBNote *)note completion:(void (^)(void))handler
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
			[self.progressSpinner stopAnimation:nil];
			[self reloadRowForNote:note];
			if (handler) {
				handler();
			}
		});
	}];
}

- (void) syncFromTimer:(NSTimer *)timer
{
	@synchronized (self.editedNotes) {
		if (self.editedNotes.count > 0) {
			for (MBNote* n in self.editedNotes) {
				[self syncNote:n completion:nil];
			}
			
			[self.editedNotes removeAllObjects];
		}
	}
}

- (void) reloadRowForNote:(MBNote *)note
{
	for (NSInteger i = 0; i < self.currentNotes.count; i++) {
		MBNote* n = [self.currentNotes objectAtIndex:i];
		if (note.noteID && [n.noteID isEqualToNumber:note.noteID]) {
			// copy the edited note and insert into array
			MBNote* note_copy = [note copy];
			NSMutableArray* new_notes = [self.currentNotes mutableCopy];
			[new_notes replaceObjectAtIndex:i withObject:note_copy];
			
			// update the cell view
			id cell = [self.tableView rowViewAtRow:i makeIfNecessary:NO];
			if ([cell isKindOfClass:[MBNoteCell class]]) {
				MBNoteCell* view = (MBNoteCell *)cell;
				[view setupWithNote:note_copy];
			}
			
			self.currentNotes = new_notes;
			
			break;
		}
	}
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
	
	[self syncNote:n completion:^{
		// reload so we get new ID
		[self fetchNotesWithCompletion:^{
			// select new note
			NSIndexSet* index = [NSIndexSet indexSetWithIndex:0];
			[self.tableView selectRowIndexes:index byExtendingSelection:NO];
			
			// focus note editor
			[self.view.window makeFirstResponder:self.detailTextView];
		}];
	}];
}

- (void) notesKeyUpdatedNotification:(NSNotification *)notification
{
	[self setupSecretKey];
	[self fetchNotes];
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length == 0) {
		self.currentNotes = self.allNotes;
		[self.tableView reloadData];
	}
	else {
		NSMutableArray* filtered_notes = [NSMutableArray array];
		for (MBNote* n in self.allNotes) {
			if ([[n.text lowercaseString] containsString:s]) {
				[filtered_notes addObject:n];
			}
		}

		self.currentNotes = filtered_notes;
		[self.tableView reloadData];
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

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
	// force a sync if selection is changing
	[self syncFromTimer:nil];
	
	// update current edited note text
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		self.selectedNote = [n copy];
		[self.detailTextView setString:self.selectedNote.text];
	}
	else {
		self.selectedNote = nil;
	}
}

#pragma mark -

- (void) textDidChange:(NSNotification *)notification
{
	if (self.selectedNote) {
		self.selectedNote.text = [self.detailTextView string];
		[self.editedNotes addObject:self.selectedNote];
	}
}

@end
