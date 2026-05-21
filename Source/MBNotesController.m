//
//  MBNotesController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNotesController.h"

#import "MBNote.h"
#import "MBNotebook.h"
#import "MBNoteCell.h"
#import "MBBook.h"
#import "MBNotesKeyController.h"
#import "MBVersionsController.h"
#import "MBBookCoverView.h"
#import "MBNotesDatabase.h"
#import "RFClient.h"
#import "RFAccount.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "NSString+Extras.h"
#import "NSAlert+Extras.h"
#import "NSColor+Extras.h"
#import "SAMKeychain.h"
#import "NSAppearance+Extras.h"

static NSString* const kNotesCloudContainer = @"iCloud.blog.micro.shared";
static NSString* const kNotesSettingsType = @"Setting";

@interface MBNotesController ()

@property (assign, nonatomic) BOOL isFetchingNotes;
@property (assign, nonatomic) BOOL shouldStartNewNoteAfterFetch;
@property (strong, nonatomic, nullable) MBNote* noteCreatedWhileFetching;

@end

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
	[self setupBrowser];
	
	[self fetchNotes];
	[self saveKeyToCloud];
}

- (void) setupSecretKey
{
	NSString* s = [SAMKeychain passwordForService:@"Micro.blog Notes" account:@""];
	if (s) {
		// use key in Keychain
		if ([s containsString:@"mkey"]) {
			self.secretKey = [s substringFromIndex:4];
		}
		else {
			self.secretKey = s;
		}
	}
	else {
		// try to find key on iCloud
		[self fetchKeyFromCloudWithCompletion:^(NSString* key) {
			if (key == nil) {
				// a bit hacky, prompt for new key
				RFDispatchSeconds(1.0, ^{
					self.notesKeyController = [[MBNotesKeyController alloc] init];
					[self.view.window beginSheet:self.notesKeyController.window completionHandler:^(NSModalResponse returnCode) {
						self.notesKeyController = nil;
					}];
				});
			}
			else {
				NSString* key_with_prefix = key;
				if ([key containsString:@"mkey"]) {
					self.secretKey = [key substringFromIndex:4];
				}
				else {
					self.secretKey = key;
					key_with_prefix = [@"mkey" stringByAppendingString:key];
				}
				[SAMKeychain setPassword:key_with_prefix forService:@"Micro.blog Notes" account:@""];
				[self fetchNotes];
			}
		}];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshNotesNotification:) name:kRefreshNotesNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeAppearanceDidChangeNotification:) name:kDarkModeAppearanceDidChangeNotification object:nil];
}

- (void) setupTimer
{
	[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(syncFromTimer:) userInfo:nil repeats:YES];
}

- (void) setupDetail
{
	[self.detailTextView setFont:[NSFont systemFontOfSize:14]];
	[self setDetailText:@"" forNote:nil];
	[self setDetailBook:@"" title:@""];
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) setupMenuForNote:(MBNote *)note
{
    if (note.isShared) {
        [self.shareMenuItem setTitle:@"Unshare"];
    }
    else {
        [self.shareMenuItem setTitle:@"Share"];
    }
}

- (void) updateDetailSharingFooter
{
    if (self.selectedNote && self.selectedNote.isShared) {
        [self.sharedLinkButton setTitle:self.selectedNote.sharedURL ?: @""];
        self.sharedHeightConstraint.constant = 40;
    }
    else {
        self.sharedHeightConstraint.constant = 0;
    }

    [self.view layoutSubtreeIfNeeded];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(openInBrowser:)) {
		return self.selectedNote.isShared;
	}
	else if (item.action == @selector(copyLink:)) {
		return self.selectedNote.isShared;
	}

	return YES;
}

#pragma mark -

- (void) fetchNotes
{
	if (self.secretKey == nil) {
		return;
	}

	[self.progressSpinner startAnimation:nil];
	self.isFetchingNotes = YES;

	[self fetchNotebooksWithCompletion:^{
		if (self.currentNotebook) {
			[self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:^{
				[self saveNotesToDisk];
			}];
		}
		else {
			self.isFetchingNotes = NO;
		}
	}];
}

- (void) fetchNotebooksWithCompletion:(void (^)(void))handler
{
	if (self.secretKey == nil) {
		return;
	}

	NSMutableArray* new_notebooks = [[NSMutableArray alloc] init];
	
	RFClient* notebooks_client = [[RFClient alloc] initWithPath:@"/notes/notebooks"];
	[notebooks_client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			for (NSDictionary* item in [response.parsedResponse objectForKey:@"items"]) {
				NSDictionary* mb = [item objectForKey:@"_microblog"];
				NSNumber* notebook_id = [item objectForKey:@"id"];
				NSString* notebook_name = [item objectForKey:@"title"];
				NSString* light_color = [[mb objectForKey:@"colors"] objectForKey:@"light"];
				NSString* dark_color = [[mb objectForKey:@"colors"] objectForKey:@"dark"];
			
				MBNotebook* nb = [[MBNotebook alloc] init];
				nb.notebookID = notebook_id;
				nb.name = notebook_name;
				nb.lightColor = [NSColor mb_colorFromString:light_color];
				nb.darkColor = [NSColor mb_colorFromString:dark_color];
				[new_notebooks addObject:nb];
				
				// assume first notebook
				if (self.currentNotebook == nil) {
					self.currentNotebook = nb;
					[self updateDetailsColor];
				}
				
				// if saved notebook, use that
				NSNumber* saved_notebook_id = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentNotebookIDPrefKey];
				if (saved_notebook_id && [saved_notebook_id isEqualToNumber:nb.notebookID]) {
					self.currentNotebook = nb;
					[self updateDetailsColor];
				}
			}
			
			RFDispatchMainAsync(^{
				self.notebooks = new_notebooks;

				[self.notebooksPopup removeAllItems];
				
				for (MBNotebook* nb in new_notebooks) {
					NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:nb.name action:NULL keyEquivalent:@""];
					item.tag = [nb.notebookID integerValue];
					[self.notebooksPopup.menu addItem:item];
				}
				
				// update selected menu item
				if (self.currentNotebook) {
					[self.notebooksPopup selectItemWithTag:[self.currentNotebook.notebookID integerValue]];
				}

				handler();
			});
		}
		else {
			RFDispatchMainAsync(^{
				handler();
			});
		}
	}];
}

- (void) fetchNotesWithNotebookID:(NSNumber *)notebookID completion:(void (^)(void))handler
{
	if (self.secretKey == nil) {
		return;
	}

	self.isFetchingNotes = YES;

	NSMutableArray* cached_notes = [[self cachedNotesWithNotebookID:notebookID] mutableCopy];
	NSMutableSet* cached_note_ids = [self noteIDsFromNotes:cached_notes];
	NSMutableSet* server_note_ids = [NSMutableSet set];

	if (cached_notes.count > 0) {
		self.allNotes = cached_notes;
		self.currentNotes = cached_notes;
		if (self.searchField.stringValue.length > 0) {
			[self runSearch:self.searchField.stringValue];
		}
		else {
			[self.tableView reloadData];
		}
	}

	[self fetchNotesWithNotebookID:notebookID offset:0 notesArray:cached_notes cachedNoteIDs:cached_note_ids serverNoteIDs:server_note_ids completion:^{
		self.isFetchingNotes = NO;

		if (handler) {
			handler();
		}

		self.noteCreatedWhileFetching = nil;
	}];
}

- (NSArray *) cachedNotesWithNotebookID:(NSNumber *)notebookID
{
	if (![MBNotesDatabase databaseExists]) {
		return @[];
	}

	MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
	NSArray* notes = [db notesWithNotebookID:notebookID];
	[db close];

	return notes;
}

- (NSMutableSet *) noteIDsFromNotes:(NSArray *)notes
{
	NSMutableSet* note_ids = [NSMutableSet set];

	for (MBNote* note in notes) {
		if (note.noteID) {
			[note_ids addObject:note.noteID];
		}
	}

	return note_ids;
}

- (void) mergeNotes:(NSArray *)notes intoNotesArray:(NSMutableArray *)array atOffset:(NSInteger)offset
{
	if (notes.count == 0) {
		return;
	}

	NSSet* note_ids = [self noteIDsFromNotes:notes];
	NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];

	for (NSInteger i = 0; i < array.count; i++) {
		MBNote* note = [array objectAtIndex:i];
		if (note.noteID && [note_ids containsObject:note.noteID]) {
			[indexes addIndex:i];
		}
	}

	[array removeObjectsAtIndexes:indexes];

	NSInteger insert_index = MIN(offset, array.count);
	NSIndexSet* insert_indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insert_index, notes.count)];
	[array insertObjects:notes atIndexes:insert_indexes];
}

- (void) removeNotesFromArray:(NSMutableArray *)array notInNoteIDs:(NSSet *)noteIDs
{
	NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];

	for (NSInteger i = 0; i < array.count; i++) {
		MBNote* note = [array objectAtIndex:i];
		if (note.noteID && ![noteIDs containsObject:note.noteID]) {
			[indexes addIndex:i];
		}
	}

	[array removeObjectsAtIndexes:indexes];
}

- (NSArray *) notesArrayByIncludingNewNoteIfNeeded:(NSArray *)notes
{
	if (self.noteCreatedWhileFetching == nil) {
		return notes;
	}

	NSMutableArray* new_notes = [notes mutableCopy];
	for (NSInteger i = new_notes.count - 1; i >= 0; i--) {
		MBNote* n = [new_notes objectAtIndex:i];
		if ((n == self.noteCreatedWhileFetching) || (n.noteID && self.noteCreatedWhileFetching.noteID && [n.noteID isEqualToNumber:self.noteCreatedWhileFetching.noteID])) {
			[new_notes removeObjectAtIndex:i];
		}
	}

	[new_notes insertObject:self.noteCreatedWhileFetching atIndex:0];
	return new_notes;
}

- (void) startNewNoteAfterFirstBatchIfNeeded
{
	if (self.shouldStartNewNoteAfterFetch) {
		self.shouldStartNewNoteAfterFetch = NO;
		[self createNewNote];
	}
}

- (void) fetchNotesWithNotebookID:(NSNumber *)notebookID offset:(NSInteger)offset notesArray:(NSMutableArray *)array cachedNoteIDs:(NSMutableSet *)cachedNoteIDs serverNoteIDs:(NSMutableSet *)serverNoteIDs completion:(void (^)(void))handler
{
	if (self.secretKey == nil) {
		return;
	}

	// if multiple notebooks, disable until we're done loading (and only on 2nd or later request)
	if ((self.notebooks.count > 1) && (offset > 0)) {
		self.notebooksPopup.enabled = NO;
	}

	NSInteger count = 100;
	
	// remember selection if there is one
	NSNumber* selected_id = nil;
	NSInteger selected_row = [self.tableView selectedRow];
	if ((selected_row >= 0) && (selected_row < self.currentNotes.count)) {
		MBNote* n = [self.currentNotes objectAtIndex:selected_row];
		selected_id = n.noteID;
	}
	
	NSDictionary* args = @{
		@"count": @(count),
		@"offset": @(offset)
	};
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/notebooks/%@", notebookID];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_notes = [NSMutableArray array];
			BOOL all_notes_cached = YES;
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBNote* n = [MBNote noteWithDictionary:item notebookID:notebookID secretKey:self.secretKey];
				BOOL note_is_cached = (n.noteID && [cachedNoteIDs containsObject:n.noteID]);
				if (!note_is_cached) {
					all_notes_cached = NO;
				}
				if (n.noteID) {
					[serverNoteIDs addObject:n.noteID];
				}

                // if selected note, update if sharing changed
                if (self.selectedNote && self.selectedNote.noteID) {
                    if ([n.noteID isEqualToNumber:self.selectedNote.noteID]) {
                        self.selectedNote.sharedURL = n.sharedURL;
                        RFDispatchMainAsync(^{
                            [self updateDetailSharingFooter];
                            [self setupMenuForNote:self.selectedNote];
                        });
                    }
                }

				[new_notes addObject:n];
			}

			MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
			[db saveNotes:new_notes];
			[db close];
			
			for (MBNote* note in new_notes) {
				if (note.noteID) {
					[cachedNoteIDs addObject:note.noteID];
				}
			}

			[self mergeNotes:new_notes intoNotesArray:array atOffset:offset];
			
			RFDispatchMainAsync(^{
				BOOL reached_end = (items.count < count);
				BOOL should_stop_paging = (reached_end || all_notes_cached);

				if (should_stop_paging) {
					if (reached_end) {
						[self removeNotesFromArray:array notInNoteIDs:serverNoteIDs];
					}

					NSArray* updated_notes = [self notesArrayByIncludingNewNoteIfNeeded:array];
					self.allNotes = updated_notes;
					self.currentNotes = updated_notes;
					if (self.searchField.stringValue.length > 0) {
						[self runSearch:self.searchField.stringValue];
					}
					else {
						[self.tableView reloadData];
					}
					if (offset == 0) {
						[self startNewNoteAfterFirstBatchIfNeeded];
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
					else if (self.noteCreatedWhileFetching) {
						NSInteger row = [self.currentNotes indexOfObjectIdenticalTo:self.noteCreatedWhileFetching];
						if (row != NSNotFound) {
							NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:row];
							[self.tableView selectRowIndexes:index_set byExtendingSelection:NO];
							[self.view.window makeFirstResponder:self.detailTextView];
						}
					}
					if (handler) {
						handler();
					}

					self.notebooksPopup.enabled = YES;
					[self.progressSpinner stopAnimation:nil];
					[self stopLoadingSidebarRow];
				}
				else {
					// if this was the first page, show results right away
					if (offset == 0) {
						NSArray* updated_notes = [self notesArrayByIncludingNewNoteIfNeeded:array];
						self.allNotes = updated_notes;
						self.currentNotes = updated_notes;
						[self.tableView reloadData];
						[self startNewNoteAfterFirstBatchIfNeeded];
					}

					// fetch another page
					NSLog(@"Fetching another page of notes, offset: %ld", (long)offset);
					NSInteger new_offset = offset + count;
					[self fetchNotesWithNotebookID:notebookID offset:new_offset notesArray:array cachedNoteIDs:cachedNoteIDs serverNoteIDs:serverNoteIDs completion:handler];
				}
			});
		}
		else {
			RFDispatchMainAsync(^{
				if (handler) {
					handler();
				}

				self.notebooksPopup.enabled = YES;
				[self.progressSpinner stopAnimation:nil];
				[self stopLoadingSidebarRow];
			});
		}
	}];
}

- (void) fetchKeyFromCloudWithCompletion:(void (^)(NSString* key))handler
{
	CKContainer* container = [CKContainer containerWithIdentifier:kNotesCloudContainer];

	[container accountStatusWithCompletionHandler:^(CKAccountStatus status, NSError* error) {
		if (status != CKAccountStatusAvailable) {
			NSLog(@"iCloud: User not signed in to iCloud.");
		}
		else {
			CKDatabase* db = [container privateCloudDatabase];
			
			NSPredicate* predicate = [NSPredicate predicateWithValue:YES]; // match all records of type
			CKQuery* query = [[CKQuery alloc] initWithRecordType:kNotesSettingsType predicate:predicate];
			
			CKQueryOperation* op = [[CKQueryOperation alloc] initWithQuery:query];
			op.resultsLimit = 1;
			
			__block NSString* found_key = nil;
			
			[op setRecordFetchedBlock:^(CKRecord* record) {
				NSLog(@"iCloud: Got Record: %@", record);
				found_key = [record objectForKey:@"notesKey"];
			}];

			[op setQueryCompletionBlock:^(CKQueryCursor* cursor, NSError* error) {
				if (error) {
					NSLog(@"iCloud: Error querying records: %@", error);
					handler(nil);
				}
				else {
					NSLog(@"iCloud: Query successful.");
					handler(found_key);
				}
			}];

			[db addOperation:op];
		}
	}];
}

- (void) saveKeyToCloud
{
	if ((self.secretKey == nil) || ![[NSUserDefaults standardUserDefaults] boolForKey:kSaveKeyToCloudPrefKey]) {
		return;
	}
	
	CKContainer* container = [CKContainer containerWithIdentifier:kNotesCloudContainer];

	[container accountStatusWithCompletionHandler:^(CKAccountStatus status, NSError* error) {
		if (status != CKAccountStatusAvailable) {
			NSLog(@"iCloud: User not signed in to iCloud.");
		}
		else {
			CKDatabase* db = [container privateCloudDatabase];
			CKRecord* record = [[CKRecord alloc] initWithRecordType:kNotesSettingsType];

			NSString* s = [@"mkey" stringByAppendingString:self.secretKey];
			[record setObject:s forKey:@"notesKey"];
			
			[db saveRecord:record completionHandler:^(CKRecord* record, NSError* error) {
				if (error) {
					NSLog(@"iCloud: Error saving record: %@", error);
				}
				else {
					NSLog(@"iCloud: Saved secret key to the cloud.");
				}
			}];
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

- (void) saveNotesToDisk
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kSaveNotesToFolderPrefKey]) {
		return;
	}

	NSString* notes_folder = [RFAccount notesFolder];
	for (MBNote* n in self.allNotes) {
		// for now we're using note IDs, later need small db to track better filenames
		if (n.noteID != nil) {
			NSString* filename = [NSString stringWithFormat:@"%@.md", n.noteID];
			NSString* path = [notes_folder stringByAppendingPathComponent:filename];
			[n.text writeToFile:path atomically:NO];
		}
	}
}

- (void) updateDetailsColor
{
	RFDispatchMainAsync(^{
		// adjust text background to notebook color
		NSColor* base_color;
		if ([NSAppearance rf_isDarkMode]) {
			base_color = self.currentNotebook.darkColor;
		}
		else {
			base_color = self.currentNotebook.lightColor;
		}
		self.detailTextView.backgroundColor = base_color;

		// darken the base color for the book header and shared footer
		NSColor* darker_color = [base_color blendedColorWithFraction:0.05 ofColor:[NSColor blackColor]];
		self.bookHeader.fillColor = darker_color;
		self.sharedFooter.fillColor = darker_color;
	});
}

- (void) runSearch:(NSString *)search
{
	NSString* s = [search lowercaseString];
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

		NSString* trimmed_text = [n.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString* title = @"Delete empty note?";
		if (trimmed_text.length > 0) {
			NSString* s = [trimmed_text stringByReplacingOccurrencesOfString:@"#" withString:@""];
			s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
			s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
			s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (s.length > 20) {
				s = [s substringToIndex:20];
				s = [s stringByAppendingString:@"..."];
			}
			if (s.length > 0) {
				title = [NSString stringWithFormat:@"Delete \"%@\"?", s];
			}
			else {
				title = @"Delete note?";
			}
		}
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = title;
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
				[self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:nil];
			}
			
			self.detailTextView.string = @"";
			self.selectedNote = nil;
			[self setDetailBook:@"" title:@""];
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
			@"is_encrypted": @(YES),
			@"notebook_id": note.notebookID
		};
	}
	else {
		args = @{
			@"id": note.noteID,
			@"text": s,
			@"is_encrypted": [NSNumber numberWithBool:note.isEncrypted],
			@"notebook_id": note.notebookID
		};
	}
	
	if (note.isSharing) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:[NSNumber numberWithBool:YES] forKey:@"is_sharing"];
		args = new_args;
	}
	else if (note.isUnsharing) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:[NSNumber numberWithBool:YES] forKey:@"is_unsharing"];
		args = new_args;
	}
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			if (note.noteID == nil) {
				note.noteID = [response.parsedResponse objectForKey:@"id"];
			}
			
			[self.progressSpinner stopAnimation:nil];
			[self reloadRowForNote:note onlyRecentNotes:NO];
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

- (void) reloadRowForNote:(MBNote *)note onlyRecentNotes:(BOOL)onlyRecentNotes
{
	NSInteger recent_limit = 5;
	NSInteger use_limit = self.currentNotes.count;
	if (onlyRecentNotes && (use_limit > recent_limit)) {
		use_limit = recent_limit;
	}
	
	for (NSInteger i = 0; i < use_limit; i++) {
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

- (MBNote *) findNote:(MBNote *)note inArray:(NSArray *)array
{
	MBNote* result = nil;
	
	for (MBNote* n in array) {
		if ([n.noteID isEqualToNumber:note.noteID]) {
			return n;
		}
	}
	
	return result;
}

- (IBAction) currentNotebookChanged:(id)sender
{
	NSMenuItem* item = [sender selectedItem];
	NSInteger notebook_id = item.tag;
	
	for (MBNotebook* nb in self.notebooks) {
		if (nb.notebookID.integerValue == notebook_id) {
			self.currentNotebook = nb;
			[[NSUserDefaults standardUserDefaults] setObject:nb.notebookID forKey:kCurrentNotebookIDPrefKey];
			[self updateDetailsColor];
			break;
		}
	}

	[self.progressSpinner startAnimation:nil];

	[self fetchNotesWithNotebookID:@(notebook_id) completion:^{
	}];
	
	self.detailTextView.string = @"";
	self.selectedNote = nil;
	[self setDetailBook:@"" title:@""];
}

- (void) startNewNoteNotification:(NSNotification *)notification
{
	[self startNewNote];
}

- (void) startNewNote
{
	if (self.secretKey == nil) {
		return;
	}

	if (self.isFetchingNotes || (self.currentNotebook == nil) || (self.allNotes == nil)) {
		self.shouldStartNewNoteAfterFetch = YES;
		if (!self.isFetchingNotes) {
			[self fetchNotes];
		}
	}
	else {
		[self createNewNote];
	}
}

- (void) createNewNote
{
	MBNote* n = [[MBNote alloc] init];
	n.text = @"";
	n.notebookID = self.currentNotebook.notebookID;
	n.isEncrypted = YES;
	n.createdAt = [NSDate date];
	
	NSMutableArray* new_notes = self.allNotes ? [self.allNotes mutableCopy] : [NSMutableArray array];
	[new_notes insertObject:n atIndex:0];
	
	if (self.isFetchingNotes) {
		self.noteCreatedWhileFetching = n;
	}

	self.allNotes = new_notes;
	self.currentNotes = new_notes;
	[self.tableView reloadData];
	
	[self syncNote:n completion:^{
		// select new note
		NSIndexSet* index = [NSIndexSet indexSetWithIndex:0];
		[self.tableView selectRowIndexes:index byExtendingSelection:NO];
		
		// focus note editor
		[self.view.window makeFirstResponder:self.detailTextView];
	}];
}

- (void) notesKeyUpdatedNotification:(NSNotification *)notification
{
	[self setupSecretKey];
	[self fetchNotes];
}

- (void) refreshNotesNotification:(NSNotification *)notification
{
	[self.tableView deselectAll:nil];
	[self fetchNotes];
}

- (void) darkModeAppearanceDidChangeNotification:(NSNotification *)notification
{
	[self updateDetailsColor];
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (void) deselectAll
{
	[self.tableView deselectAll:nil];

	[self setDetailText:@"" forNote:nil];
	[self setDetailBook:@"" title:@""];
	self.selectedNote = nil;
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	[self runSearch:s];
}

- (IBAction) startNewPost:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		
		NSString* s = n.text;
		
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"microblog://post?text=%@", [s rf_urlEncoded]]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) showVersions:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		self.versionsController = [[MBVersionsController alloc] initWithNote:n secretKey:self.secretKey];
		NSWindow* win = self.versionsController.window;
		[self.tableView.window beginSheet:win completionHandler:^(NSModalResponse returnCode) {
			self.versionsController = nil;
		}];
	}
}

- (IBAction) shareOrUnshare:(id)sender
{
    [self.progressSpinner startAnimation:nil];
    
    if (self.selectedNote.isShared) {
        self.selectedNote.isUnsharing = YES;
        [self syncNote:self.selectedNote completion:^{
            self.selectedNote.isShared = NO;
            self.selectedNote.isUnsharing = NO;

            [self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:^{
                [self.progressSpinner stopAnimation:nil];
                [self updateDetailSharingFooter];
                [self setupMenuForNote:self.selectedNote];
            }];
        }];
    }
    else {
        self.selectedNote.isSharing = YES;
        self.selectedNote.isEncrypted = NO;
        [self syncNote:self.selectedNote completion:^{
            self.selectedNote.isShared = YES;
            self.selectedNote.isSharing = NO;

            [self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:^{
                [self.progressSpinner stopAnimation:nil];
                [self updateDetailSharingFooter];
                [self setupMenuForNote:self.selectedNote];
            }];
        }];
    }
}

- (IBAction) openInBrowser:(id)sender
{
	if (self.selectedNote) {
		NSURL* url = [NSURL URLWithString:self.selectedNote.sharedURL];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:self.selectedNote.sharedURL forType:NSPasteboardTypeString];
}

- (IBAction) applyFormatBold:(id)sender
{
	[self replaceSelectionBySurrounding:@[ @"**", @"**" ]];
}

- (IBAction) applyFormatItalic:(id)sender
{
	[self replaceSelectionBySurrounding:@[ @"_", @"_" ]];
}

- (IBAction) applyFormatLink:(id)sender
{
	NSRange r = self.detailTextView.selectedRange;
	if (r.length == 0) {
		[self replaceSelectionBySurrounding:@[ @"[]()" ]];
		r = self.detailTextView.selectedRange;
		r.location = r.location - 3;
		self.detailTextView.selectedRange = r;
	}
	else {
		[self replaceSelectionBySurrounding:@[ @"[", @"]()" ]];

		NSInteger markdown_length = [@"[]()" length];
		r.location = r.location + r.length + markdown_length - 1;
		r.length = 0;
		self.detailTextView.selectedRange = r;
	}
}

- (IBAction) sharedLinkClicked:(id)sender
{
	if (self.selectedNote && self.selectedNote.isShared) {
		NSURL* url = [NSURL URLWithString:self.selectedNote.sharedURL];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

#pragma mark -

- (void) replaceSelectionBySurrounding:(NSArray *)markup
{
	NSRange r = self.detailTextView.selectedRange;
	if (r.length == 0) {
		[self.detailTextView replaceCharactersInRange:r withString:[markup firstObject]];
		r.location = r.location + [markup.firstObject length];
		self.detailTextView.selectedRange = r;
	}
	else {
		NSString* s = [self.detailTextView.string substringWithRange:r];
		NSString* new_s = [NSString stringWithFormat:@"%@%@%@", [markup firstObject], s, [markup lastObject]];
		[self.detailTextView replaceCharactersInRange:r withString:new_s];

		NSInteger markdown_length = [[markup componentsJoinedByString:@""] length];
		r.location = r.location + r.length + markdown_length;
		r.length = 0;
		self.detailTextView.selectedRange = r;
	}
}

- (void) setDetailText:(NSString *)text forNote:(MBNote *)note
{
	[self.detailTextView setString:text];
	if (note && note.isShared) {
		[self.sharedLinkButton setTitle:note.sharedURL];
		self.sharedHeightConstraint.constant = 40;
	}
	else {
		self.sharedHeightConstraint.constant = 0;
	}
}

- (void) setDetailBook:(NSString *)isbn title:(NSString *)title
{
	if ([isbn length] > 0) {
		// make temp book object
		MBBook* b = [[MBBook alloc] init];
		b.isbn = isbn;
		b.title = title;

		[self.bookImageView setupWithBook:b];
		[self.bookTitleField setStringValue:title];
		self.bookHeightConstraint.constant = 44;
	}
	else {
		self.bookHeightConstraint.constant = 0;
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
	
	// update current edited note text (if not already being edited)
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		if (![self.selectedNote.noteID isEqualToNumber:n.noteID]) {
			self.selectedNote = [n copy];
			[self setDetailText:self.selectedNote.text forNote:self.selectedNote];
			[self setDetailBook:self.selectedNote.attachedBookISBN title:self.selectedNote.attachedBookTitle];
			[self setupMenuForNote:self.selectedNote];
		}
	}
	else {
		self.selectedNote = nil;
		[self setDetailText:@"" forNote:nil];
		[self setDetailBook:@"" title:@""];
	}
}

#pragma mark -

- (void) textDidChange:(NSNotification *)notification
{
	if (self.selectedNote) {
		// add to sync queue
		self.selectedNote.text = [self.detailTextView string];
		[self.editedNotes addObject:self.selectedNote];
		
		// also update the copy in the notes list
		MBNote* n;
		n = [self findNote:self.selectedNote inArray:self.currentNotes];
		if (n) {
			n.text = self.selectedNote.text;
		}
		n = [self findNote:self.selectedNote inArray:self.allNotes];
		if (n) {
			n.text = self.selectedNote.text;
		}

		// do a quick reload of the table row before it syncs
		if (n) {
			[self reloadRowForNote:n onlyRecentNotes:YES];
		}
	}
}

@end
