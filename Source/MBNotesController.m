//
//  MBNotesController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNotesController.h"
#import "MBNotesTextView.h"
#import "MBAudioNoteController.h"

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
#import "NSError+Extras.h"
#import "NSColor+Extras.h"
#import "SAMKeychain.h"
#import "NSAppearance+Extras.h"

static NSString* const kNotesCloudContainer = @"iCloud.blog.micro.shared";
static NSString* const kNotesSettingsType = @"Setting";

@interface MBNotesController ()

@property (assign, nonatomic) BOOL isFetchingNotes;
@property (assign, nonatomic) NSInteger notesFetchRequestID;
@property (strong, nonatomic) NSMutableArray* localNotes;
@property (strong, nonatomic, nullable) NSArray* pendingNotesList;
@property (strong, nonatomic) NSMutableSet* syncingNotes;
@property (strong, nonatomic) NSMutableSet* failedNotes;
@property (strong, nonatomic) NSMapTable* noteSyncCompletions;
@property (assign, nonatomic) BOOL isUpdatingNotesList;
@property (strong, nonatomic) NSMutableSet* deletingNoteIDs;
@property (strong, nonatomic) NSMutableSet* deletedNoteIDs;
@property (strong, nonatomic) NSUndoManager* textUndoManager;
@property (strong, nonatomic) NSMutableSet* audioNoteControllers;
@property (assign, nonatomic) BOOL isShowingNotesProgress;
@property (assign, nonatomic) BOOL isWaitingToRecordAudioNote;

@end

@implementation MBNotesController

- (id) init
{
	self = [super initWithNibName:@"Notes" bundle:nil];
	if (self) {
		self.editedNotes = [NSMutableSet set];
		self.localNotes = [NSMutableArray array];
		self.syncingNotes = [NSMutableSet set];
		self.failedNotes = [NSMutableSet set];
		self.noteSyncCompletions = [NSMapTable strongToStrongObjectsMapTable];
		self.deletingNoteIDs = [NSMutableSet set];
		self.deletedNoteIDs = [NSMutableSet set];
		self.textUndoManager = [[NSUndoManager alloc] init];
		self.audioNoteControllers = [NSMutableSet set];
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupSecretKey];
	[self setupTable];
	[self setupSplitView];
	[self setupNotifications];
	[self setupTimer];
	[self setupDetail];
	[self setupBrowser];
	
	[self fetchNotes];
	[self saveKeyToCloud];
}

- (void) setupSplitView
{
	NSString* autosave_name = @"NotesSplitView";
	NSString* defaults_key = [NSString stringWithFormat:@"NSSplitView Subview Frames %@", autosave_name];
	BOOL has_saved_position = ([[NSUserDefaults standardUserDefaults] objectForKey:defaults_key] != nil);

	[self.splitView setAutosaveName:autosave_name];

	if (!has_saved_position) {
		RFDispatchMainAsync(^{
			[self.view layoutSubtreeIfNeeded];
			[self.splitView setPosition:(self.splitView.bounds.size.width / 2.0) ofDividerAtIndex:0];
		});
	}
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
			RFDispatchMainAsync(^{
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
			});
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
	[(MBNotesTextView *)self.detailTextView setupMarkdownWithFontSize:14];
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

	[self startNotesProgress];
	self.isFetchingNotes = YES;
	self.notesFetchRequestID++;
	self.pendingNotesList = nil;

	[self fetchNotebooksWithCompletion:^{
		if (self.currentNotebook) {
			// Notes created during the initial notebook request are already editable.
			for (MBNote* note in self.localNotes) {
				if (!note.notebookID) {
					note.notebookID = self.currentNotebook.notebookID;
				}
			}
			[self syncFromTimer:nil];
			[self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:nil finishedCompletion:^{
				[self saveNotesToDisk];
			}];
		}
		else {
			self.isFetchingNotes = NO;
			[self stopNotesProgress];
		}
	}];
}

- (void) fetchNotebooksWithCompletion:(void (^)(void))handler
{
	if (self.secretKey == nil) {
		return;
	}

	NSMutableArray* new_notebooks = [[NSMutableArray alloc] init];
	NSInteger request_id = self.notesFetchRequestID;
	
	RFClient* notebooks_client = [[RFClient alloc] initWithPath:@"/notes/notebooks"];
	[notebooks_client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		id items = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse[@"items"] : nil;
		if (!response.httpError && [items isKindOfClass:[NSArray class]] && [items count] > 0) {
			for (NSDictionary* item in items) {
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
			}
			
			RFDispatchMainAsync(^{
				if (request_id != self.notesFetchRequestID) {
					return;
				}
				self.notebooks = new_notebooks;
				NSNumber* notebook_id = self.currentNotebook.notebookID ?: [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentNotebookIDPrefKey];
				self.currentNotebook = new_notebooks.firstObject;
				for (MBNotebook* nb in new_notebooks) {
					if (notebook_id && [nb.notebookID isEqualToNumber:notebook_id]) {
						self.currentNotebook = nb;
						break;
					}
				}
				[self updateDetailsColor];

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
				if (request_id == self.notesFetchRequestID) {
					handler();
				}
			});
		}
	}];
}

- (void) fetchNotesWithNotebookID:(NSNumber *)notebookID completion:(void (^)(void))handler
{
	[self fetchNotesWithNotebookID:notebookID completion:handler finishedCompletion:nil];
}

- (void) fetchNotesWithNotebookID:(NSNumber *)notebookID completion:(void (^)(void))handler finishedCompletion:(void (^)(void))finishedHandler
{
	if (self.secretKey == nil) {
		return;
	}

	self.isFetchingNotes = YES;

	// Keep pending edits across refreshes; protect new changes until this fetch finishes.
	NSIndexSet* saved_indexes = [self.localNotes indexesOfObjectsPassingTest:^BOOL(MBNote* note, NSUInteger index, BOOL* stop) {
		return note.noteID && ![self.editedNotes containsObject:note] && ![self.syncingNotes containsObject:note];
	}];
	[self.localNotes removeObjectsAtIndexes:saved_indexes];
	self.notesFetchRequestID++;
	self.pendingNotesList = nil;
	NSInteger request_id = self.notesFetchRequestID;

	NSMutableArray* cached_notes = [[self cachedNotesWithNotebookID:notebookID] mutableCopy];
	NSMutableSet* cached_note_ids = [self noteIDsFromNotes:cached_notes];
	NSMutableSet* server_note_ids = [NSMutableSet set];

	[self updateNotesListWithArray:cached_notes notebookID:notebookID];

	__block BOOL did_finish_initial_load = NO;
	void (^initial_handler)(void) = ^{
		if (did_finish_initial_load) {
			return;
		}

		did_finish_initial_load = YES;
		self.isFetchingNotes = NO;

		if (handler) {
			handler();
		}
	};

	[self fetchNotesWithNotebookID:notebookID offset:0 notesArray:cached_notes cachedNoteIDs:cached_note_ids serverNoteIDs:server_note_ids requestID:request_id completion:initial_handler finishedCompletion:finishedHandler];
}

- (NSArray *) cachedNotesWithNotebookID:(NSNumber *)notebookID
{
	if (![MBNotesDatabase databaseExists]) {
		return @[];
	}

	MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
	NSArray* notes = [db notesWithNotebookID:notebookID];
	[db close];

	return [self notesByExcludingDeletedNotes:notes];
}

- (NSArray *) notesByExcludingDeletedNotes:(NSArray *)notes
{
	if (self.deletedNoteIDs.count == 0) {
		return notes;
	}

	return [notes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MBNote* note, NSDictionary* bindings) {
		return !note.noteID || ![self.deletedNoteIDs containsObject:note.noteID];
	}]];
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

- (void) deleteCachedNotesWithNotebookID:(NSNumber *)notebookID notInNoteIDs:(NSSet *)noteIDs
{
	MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
	[db deleteNotesWithNotebookID:notebookID notInNoteIDs:noteIDs];
	[db close];
}

- (NSArray *) notesArrayByIncludingLocalNotes:(NSArray *)notes forNotebookID:(NSNumber *)notebookID
{
	NSMutableArray* new_notes = [notes mutableCopy];
	for (MBNote* note in self.localNotes) {
		if ([note.notebookID isEqualToNumber:notebookID]) {
			NSIndexSet* indexes = [new_notes indexesOfObjectsPassingTest:^BOOL(MBNote* candidate, NSUInteger index, BOOL* stop) {
				return (candidate == note) || (note.noteID && [candidate.noteID isEqualToNumber:note.noteID]);
			}];
			NSUInteger index = indexes.count ? indexes.firstIndex : 0;
			[new_notes removeObjectsAtIndexes:indexes];
			[new_notes insertObject:note atIndex:index];
		}
	}
	return new_notes;
}

- (void) finishInitialNotesLoadWithCompletion:(void (^)(void))handler
{
	if (handler) {
		handler();
	}

	self.notebooksPopup.enabled = YES;
	[self stopNotesProgress];
	[self stopLoadingSidebarRow];
}

- (void) startNotesProgress
{
	self.isShowingNotesProgress = YES;
	[self updateProgressSpinner];
}

- (void) stopNotesProgress
{
	self.isShowingNotesProgress = NO;
	[self updateProgressSpinner];
}

- (void) updateProgressSpinner
{
	BOOL should_spin = self.isShowingNotesProgress || self.syncingNotes.count > 0;
	for (MBAudioNoteController* controller in self.audioNoteControllers) {
		should_spin |= controller.isProcessing;
	}
	if (should_spin) {
		[self.progressSpinner startAnimation:nil];
	}
	else {
		[self.progressSpinner stopAnimation:nil];
	}
}

- (NSNumber *) currentSelectedNoteID
{
	return self.selectedNote.noteID;
}

- (void) updateCurrentNotesForSearch:(NSString *)search preservingSelectedNoteID:(NSNumber *)selectedID
{
	MBNote* selected_note = self.selectedNote;
	NSString* s = [search lowercaseString];
	if (s.length == 0) {
		self.currentNotes = self.allNotes;
	}
	else {
		NSMutableArray* filtered_notes = [NSMutableArray array];
		for (MBNote* n in self.allNotes) {
			if ([[n.text lowercaseString] containsString:s]) {
				[filtered_notes addObject:n];
			}
		}

		self.currentNotes = filtered_notes;
	}

	// Reloading can send selection notifications while the row indexes are changing.
	// Restore by object identity first, including notes that do not have a server ID yet.
	self.isUpdatingNotesList = YES;
	[self.tableView reloadData];
	NSUInteger selected_row = NSNotFound;
	for (NSUInteger i = 0; i < self.currentNotes.count; i++) {
		MBNote* note = self.currentNotes[i];
		if ((note == selected_note) || (selectedID && [note.noteID isEqualToNumber:selectedID])) {
			selected_row = i;
			break;
		}
	}
	if (selected_row == NSNotFound) {
		[self.tableView deselectAll:nil];
	}
	else {
		[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selected_row] byExtendingSelection:NO];
	}
	self.isUpdatingNotesList = NO;
	[self updateSelectedNote];
}

- (void) updateNotesListWithArray:(NSArray *)array notebookID:(NSNumber *)notebookID
{
	// A GET can include a newly created note before its POST returns the ID.
	// Wait to display that list so it cannot appear as a second, disconnected row.
	for (MBNote* note in self.syncingNotes) {
		if (!note.noteID && [note.notebookID isEqualToNumber:notebookID]) {
			self.pendingNotesList = [array copy];
			return;
		}
	}
	self.pendingNotesList = nil;
	NSNumber* selected_id = [self currentSelectedNoteID];
	NSArray* updated_notes = [self notesArrayByIncludingLocalNotes:array forNotebookID:notebookID];
	self.allNotes = [self notesByExcludingDeletedNotes:updated_notes];
	[self updateCurrentNotesForSearch:self.searchField.stringValue preservingSelectedNoteID:selected_id];
}

- (void) fetchNotesWithNotebookID:(NSNumber *)notebookID offset:(NSInteger)offset notesArray:(NSMutableArray *)array cachedNoteIDs:(NSMutableSet *)cachedNoteIDs serverNoteIDs:(NSMutableSet *)serverNoteIDs requestID:(NSInteger)requestID completion:(void (^)(void))handler finishedCompletion:(void (^)(void))finishedHandler
{
	if (self.secretKey == nil) {
		return;
	}

	// if multiple notebooks, disable until the visible loading phase is done
	if (self.isFetchingNotes && (self.notebooks.count > 1) && (offset > 0)) {
		self.notebooksPopup.enabled = NO;
	}

	NSInteger count = 100;
	
	NSDictionary* args = @{
		@"count": @(count),
		@"offset": @(offset)
	};
	
	NSString* secret_key = self.secretKey;
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/notebooks/%@", notebookID];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		NSDictionary* response_dict = nil;
		if (!response.httpError && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			response_dict = response.parsedResponse;
		}
		NSArray* items = [response_dict objectForKey:@"items"];

		NSMutableArray* decoded_notes = nil;
		if ([items isKindOfClass:[NSArray class]]) {
			decoded_notes = [NSMutableArray array];
			for (NSDictionary* item in items) {
				[decoded_notes addObject:[MBNote noteWithDictionary:item notebookID:notebookID secretKey:secret_key]];
			}
		}

		// Apply pages on the same queue as deletes and autosaves.
		RFDispatchMainAsync(^{
			if (requestID != self.notesFetchRequestID) {
				return;
			}
			if (!decoded_notes) {
				if (offset == 0) {
					[self finishInitialNotesLoadWithCompletion:handler];
				}
				return;
			}

			NSArray* new_notes = [self notesByExcludingDeletedNotes:decoded_notes];
			BOOL all_notes_cached = YES;
			for (MBNote* n in new_notes) {
				BOOL note_is_cached = (n.noteID && [cachedNoteIDs containsObject:n.noteID]);
				if (!note_is_cached) {
					all_notes_cached = NO;
				}
				if (n.noteID) {
					[serverNoteIDs addObject:n.noteID];
				}
			}

			MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
			// An older server page must not overwrite an edit or a completed local save.
			NSArray* cache_notes = [new_notes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MBNote* note, NSDictionary* bindings) {
				return [self findNote:note inArray:self.localNotes] == nil;
			}]];
			[db saveNotes:cache_notes];
			[db close];
			
			for (MBNote* note in new_notes) {
				if (note.noteID) {
					[cachedNoteIDs addObject:note.noteID];
				}
			}

			[self mergeNotes:new_notes intoNotesArray:array atOffset:offset];

			BOOL reached_end = (items.count < count);
			if (reached_end) {
				NSMutableSet* note_ids_to_keep = [serverNoteIDs mutableCopy];
				[note_ids_to_keep unionSet:[self noteIDsFromNotes:self.localNotes]];
				[note_ids_to_keep minusSet:self.deletedNoteIDs];

				[self deleteCachedNotesWithNotebookID:notebookID notInNoteIDs:note_ids_to_keep];
				[self removeNotesFromArray:array notInNoteIDs:note_ids_to_keep];
				[self updateNotesListWithArray:array notebookID:notebookID];

				if (offset == 0) {
					[self finishInitialNotesLoadWithCompletion:handler];
				}
				if (finishedHandler) {
					finishedHandler();
				}
			}
			else {
				if (offset == 0) {
					[self updateNotesListWithArray:array notebookID:notebookID];
					[self finishInitialNotesLoadWithCompletion:handler];
				}

				NSLog(@"Fetching another page of notes, offset: %ld, all cached: %@", (long)offset, all_notes_cached ? @"yes" : @"no");
				NSInteger new_offset = offset + count;
				[self fetchNotesWithNotebookID:notebookID offset:new_offset notesArray:array cachedNoteIDs:cachedNoteIDs serverNoteIDs:serverNoteIDs requestID:requestID completion:handler finishedCompletion:finishedHandler];
			}
		});
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
			base_color = [self.currentNotebook.lightColor blendedColorWithFraction:0.5 ofColor:[NSColor whiteColor]];
		}
		base_color = base_color ?: [NSColor colorNamed:@"color_highlight_background"];
		self.detailTextView.backgroundColor = base_color;
		self.detailTextView.enclosingScrollView.backgroundColor = base_color;
		self.detailTextView.enclosingScrollView.contentView.backgroundColor = base_color;

		// darken the base color for the book header and shared footer
		NSColor* darker_color = [base_color blendedColorWithFraction:0.05 ofColor:[NSColor blackColor]];
		self.bookHeader.fillColor = darker_color;
		self.sharedFooter.fillColor = darker_color;
	});
}

- (void) runSearch:(NSString *)search
{
	NSNumber* selected_id = [self currentSelectedNoteID];
	[self updateCurrentNotesForSearch:search preservingSelectedNoteID:selected_id];
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
	if (row >= 0 && row < self.currentNotes.count) {
		MBNote* n = [self.currentNotes objectAtIndex:row];
		if (!n.noteID || [self.deletingNoteIDs containsObject:n.noteID]) {
			return;
		}

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
	NSNumber* note_id = note.noteID;
	if (!note_id || [self.deletingNoteIDs containsObject:note_id] || [self.deletedNoteIDs containsObject:note_id]) {
		return;
	}

	[self.deletingNoteIDs addObject:note_id];
	[self startNotesProgress];
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/%@", note_id];
	[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			[self.deletingNoteIDs removeObject:note_id];
			id error = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse[@"error"] : nil;
			if (response.httpError || error) {
				[self stopNotesProgress];
				NSString* msg = [error isKindOfClass:[NSString class]] ? error : [response.httpError mb_networkMessageWithResponse:response.httpResponse];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Note" message:msg button:@"OK" completionHandler:NULL];
				return;
			}

			[self removeDeletedNoteWithID:note_id];
			if (self.secretKey && [self.currentNotebook.notebookID isEqualToNumber:note.notebookID]) {
				[self fetchNotesWithNotebookID:self.currentNotebook.notebookID completion:nil];
			}
			else {
				[self stopNotesProgress];
			}
		});
	}];
}

- (void) removeDeletedNoteWithID:(NSNumber *)noteID
{
	// Keep the ID for this session so older fetch and save responses cannot restore the note.
	[self.deletedNoteIDs addObject:noteID];
	self.localNotes = [[self notesByExcludingDeletedNotes:self.localNotes] mutableCopy];
	for (MBNote* note in [self.failedNotes copy]) {
		if ([note.noteID isEqualToNumber:noteID]) {
			[self.failedNotes removeObject:note];
			[self.noteSyncCompletions removeObjectForKey:note];
		}
	}

	@synchronized (self.editedNotes) {
		NSSet* deleted_edits = [self.editedNotes objectsPassingTest:^BOOL(MBNote* note, BOOL* stop) {
			return [note.noteID isEqualToNumber:noteID];
		}];
		[self.editedNotes minusSet:deleted_edits];
	}

	MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
	[db deleteNoteWithID:noteID];
	[db close];

	NSNumber* selected_id = [self currentSelectedNoteID];
	if ([selected_id isEqualToNumber:noteID]) {
		[self deselectAll];
		selected_id = nil;
	}
	self.allNotes = [self notesByExcludingDeletedNotes:self.allNotes];
	[self updateCurrentNotesForSearch:self.searchField.stringValue preservingSelectedNoteID:selected_id];
}

- (void) syncNote:(MBNote *)note completion:(void (^)(void))handler
{
	if (note.noteID && [self.deletedNoteIDs containsObject:note.noteID]) {
		return;
	}
	if (![self.localNotes containsObject:note]) {
		[self.localNotes addObject:note];
	}
	if (handler) {
		NSMutableArray* completions = [self.noteSyncCompletions objectForKey:note];
		if (!completions) {
			completions = [NSMutableArray array];
			[self.noteSyncCompletions setObject:completions forKey:note];
		}
		[completions addObject:[handler copy]];
	}
	if (!note.notebookID || [self.syncingNotes containsObject:note]) {
		[self.editedNotes addObject:note];
		return;
	}

	// One request per live note, especially before the first POST assigns its ID.
	MBNote* saved_note = [note copy];
	NSArray* completions = [[self.noteSyncCompletions objectForKey:note] copy];
	[self.noteSyncCompletions removeObjectForKey:note];
	[self.editedNotes removeObject:note];
	[self.failedNotes removeObject:note];
	[self.syncingNotes addObject:note];
	[self updateProgressSpinner];

	NSString* text = saved_note.text ?: @"";
	if (saved_note.isEncrypted) {
		text = [MBNote encryptText:text withKey:self.secretKey];
	}
	NSMutableDictionary* args = [@{
		@"text": text,
		@"is_encrypted": @(saved_note.isEncrypted),
		@"notebook_id": saved_note.notebookID
	} mutableCopy];
	if (saved_note.noteID) {
		args[@"id"] = saved_note.noteID;
	}
	if (saved_note.isSharing) {
		args[@"is_sharing"] = @YES;
	}
	else if (saved_note.isUnsharing) {
		args[@"is_unsharing"] = @YES;
	}

	RFClient* client = [[RFClient alloc] initWithPath:@"/notes"];
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			[self.syncingNotes removeObject:note];
			[self updateProgressSpinner];
			if (note.noteID && [self.deletedNoteIDs containsObject:note.noteID]) {
				[self.noteSyncCompletions removeObjectForKey:note];
				return;
			}

			NSDictionary* result = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse : nil;
			NSNumber* note_id = result[@"id"];
			if (response.httpError || result[@"error"] || ![note_id isKindOfClass:[NSNumber class]] || note_id.longLongValue <= 0 || (note.noteID && ![note.noteID isEqualToNumber:note_id])) {
				[self.editedNotes addObject:note];
				[self.failedNotes addObject:note];
				NSMutableArray* pending = [NSMutableArray arrayWithArray:completions ?: @[]];
				[pending addObjectsFromArray:[self.noteSyncCompletions objectForKey:note] ?: @[]];
				[self.noteSyncCompletions setObject:pending forKey:note];
				if (self.pendingNotesList && [self.currentNotebook.notebookID isEqualToNumber:note.notebookID]) {
					[self updateNotesListWithArray:self.pendingNotesList notebookID:note.notebookID];
				}
				NSString* message = @"Your changes are still in this window. Retry saving now, or continue editing to try again.";
				[NSAlert rf_showTwoButtonAlert:@"Error Saving Note" message:message okButton:@"Retry" cancelButton:@"Cancel" completionHandler:^(NSModalResponse returnCode) {
					if (returnCode == NSAlertFirstButtonReturn) {
						[self syncNote:note completion:nil];
					}
				}];
				return;
			}

			BOOL is_new_note = (note.noteID == nil);
			note.noteID = note_id;
			note.updatedAt = [NSDate date];
			saved_note.noteID = note_id;
			saved_note.updatedAt = note.updatedAt;
			NSDictionary* metadata = result[@"_microblog"];
			if ([metadata isKindOfClass:[NSDictionary class]]) {
				note.isShared = [metadata[@"is_shared"] boolValue];
				note.sharedURL = [metadata[@"shared_url"] isKindOfClass:[NSString class]] ? metadata[@"shared_url"] : nil;
				saved_note.isShared = note.isShared;
				saved_note.sharedURL = note.sharedURL;
			}

			// Cache only the text this request actually saved, not newer unsent typing.
			MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
			[db saveNote:saved_note];
			[db close];
			if (is_new_note && [self.currentNotebook.notebookID isEqualToNumber:note.notebookID]) {
				// The server list may have included this note before its create response arrived.
				[self updateNotesListWithArray:self.pendingNotesList ?: self.allNotes notebookID:note.notebookID];
			}
			[self reloadRowForNote:note onlyRecentNotes:NO];
			for (void (^completion)(void) in completions) {
				completion();
			}
			if ([self.editedNotes containsObject:note]) {
				[self syncNote:note completion:nil];
			}
		});
	}];
}

- (void) syncFromTimer:(NSTimer *)timer
{
	for (MBNote* note in [self.editedNotes copy]) {
		if (![self.syncingNotes containsObject:note] && ![self.failedNotes containsObject:note]) {
			[self syncNote:note completion:nil];
		}
	}
}

- (void) reloadRowForNote:(MBNote *)note onlyRecentNotes:(BOOL)onlyRecentNotes
{
	NSInteger use_limit = onlyRecentNotes ? MIN(5, self.currentNotes.count) : self.currentNotes.count;
	for (NSInteger i = 0; i < use_limit; i++) {
		if (self.currentNotes[i] == note) {
			id cell = [self.tableView rowViewAtRow:i makeIfNecessary:NO];
			if ([cell isKindOfClass:[MBNoteCell class]]) {
				[(MBNoteCell *)cell setupWithNote:note];
			}
			break;
		}
	}
}

- (MBNote *) findNote:(MBNote *)note inArray:(NSArray *)array
{
	for (MBNote* candidate in array) {
		if ((candidate == note) || (note.noteID && [candidate.noteID isEqualToNumber:note.noteID])) {
			return candidate;
		}
	}
	return nil;
}

- (IBAction) currentNotebookChanged:(id)sender
{
	[self syncFromTimer:nil];
	[self deselectAll];
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

	[self startNotesProgress];

	[self fetchNotesWithNotebookID:@(notebook_id) completion:nil];
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

	[self createNewNote];
	if (!self.currentNotebook && !self.isFetchingNotes) {
		[self fetchNotes];
	}
}

- (void) createNewNote
{
	[self syncFromTimer:nil];
	MBNote* note = [[MBNote alloc] init];
	note.text = @"";
	note.notebookID = self.currentNotebook.notebookID;
	note.isEncrypted = YES;
	note.createdAt = [NSDate date];
	[self.localNotes addObject:note];

	// Make the new note editable immediately, before its first save returns.
	self.searchField.stringValue = @"";
	NSMutableArray* notes = self.allNotes ? [self.allNotes mutableCopy] : [NSMutableArray array];
	[notes insertObject:note atIndex:0];
	self.allNotes = notes;
	[self updateCurrentNotesForSearch:@"" preservingSelectedNoteID:self.selectedNote.noteID];
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[self updateSelectedNote];
	[self.tableView scrollRowToVisible:0];
	[self.view.window makeFirstResponder:self.detailTextView];
	[self syncNote:note completion:nil];
}

- (void) recordAudioNote
{
	if (self.isWaitingToRecordAudioNote) {
		return;
	}
	[self recordAudioNoteWaitingIfNeeded:YES];
}

- (void) recordAudioNoteWaitingIfNeeded:(BOOL)canWait
{
	if (![RFSettings boolForKey:kIsUsingAI]) {
		return;
	}
	NSWindow* parent_window = self.view.window;
	if (!parent_window) {
		return;
	}
	if (self.view.window.attachedSheet) {
		NSBeep();
		return;
	}
	if (self.secretKey.length == 0 || self.currentNotebook.notebookID == nil) {
		if (canWait) {
			self.isWaitingToRecordAudioNote = YES;
			NSString* username = [RFSettings stringForKey:kAccountUsername];
			__weak MBNotesController* weak_self = self;
			__weak NSWindow* weak_window = parent_window;
			RFDispatchSeconds(1.0, ^{
				MBNotesController* controller = weak_self;
				controller.isWaitingToRecordAudioNote = NO;
				// Do not open a sheet after leaving Notes, closing the window, or switching accounts.
				if (!controller || !weak_window.isVisible || controller.view.window != weak_window || ![username isEqualToString:[RFSettings stringForKey:kAccountUsername]]) {
					return;
				}
				[controller recordAudioNoteWaitingIfNeeded:NO];
			});
			return;
		}
		NSAlert* alert = [[NSAlert alloc] init];
		alert.messageText = @"Notes Not Ready";
		alert.informativeText = @"Set up your notes encryption key and wait for your notebooks to load before recording.";
		[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
		return;
	}
	__weak MBNotesController* weak_self = self;
	__weak NSWindow* weak_window = parent_window;
	__block __weak MBAudioNoteController* weak_controller;
	MBAudioNoteController* controller = [[MBAudioNoteController alloc] initWithNotebookID:self.currentNotebook.notebookID secretKey:self.secretKey completion:^(MBNote* note, NSString* text, NSString* error) {
		MBNotesController* notes_controller = weak_self;
		if (!notes_controller) {
			return;
		}
		[notes_controller.audioNoteControllers removeObject:weak_controller];
		[notes_controller updateProgressSpinner];
		if (note) {
			[notes_controller didCreateAudioNote:note];
		}
		else if (error) {
			NSAlert* alert = [[NSAlert alloc] init];
			alert.messageText = @"Error Creating Audio Note";
			alert.informativeText = error;
			[alert addButtonWithTitle:@"OK"];
			if (text.length > 0) {
				[alert addButtonWithTitle:@"Copy Transcript"];
			}
			// The user may have left Notes while the transcript was processing.
			if (!weak_window) {
				return;
			}
			[alert beginSheetModalForWindow:weak_window completionHandler:^(NSModalResponse response) {
				if (response == NSAlertSecondButtonReturn) {
					[NSPasteboard.generalPasteboard clearContents];
					[NSPasteboard.generalPasteboard setString:text forType:NSPasteboardTypeString];
				}
			}];
		}
	}];
	weak_controller = controller;
	controller.processingStartedHandler = ^{
		[weak_self updateProgressSpinner];
	};
	[self.audioNoteControllers addObject:controller];
	[controller beginSheetForWindow:parent_window];
}

- (void) didCreateAudioNote:(MBNote *)note
{
	MBNotesDatabase* db = [[MBNotesDatabase alloc] init];
	[db saveNote:note];
	[db close];
	if (![self.currentNotebook.notebookID isEqualToNumber:note.notebookID]) {
		return;
	}
	[self.localNotes addObject:note];
	NSMutableArray* notes = self.allNotes ? [self.allNotes mutableCopy] : [NSMutableArray array];
	[self mergeNotes:@[note] intoNotesArray:notes atOffset:0];
	self.allNotes = notes;
	// Keep the user's current editor selection and search rather than stealing focus.
	[self updateCurrentNotesForSearch:self.searchField.stringValue preservingSelectedNoteID:self.selectedNote.noteID];
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
	[self.view.window makeFirstResponder:self.searchField];
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
	MBNote* note = self.selectedNote;
	if (!note || note.isSharing || note.isUnsharing) {
		return;
	}
	BOOL should_share = !note.isShared;
	note.isSharing = should_share;
	note.isUnsharing = !should_share;
	if (should_share) {
		note.isEncrypted = NO;
	}
	[self syncNote:note completion:^{
		note.isShared = should_share;
		note.isSharing = NO;
		note.isUnsharing = NO;
		if (self.selectedNote == note) {
			[self updateDetailSharingFooter];
			[self setupMenuForNote:note];
		}
	}];
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
	// The editor is reused across notes; undo must never restore another note's text.
	[self.detailTextView breakUndoCoalescing];
	[self.detailTextView setString:text];
	self.detailTextView.editable = (note != nil);
	[self.textUndoManager removeAllActions];
	if (note && note.isShared) {
		[self.sharedLinkButton setTitle:note.sharedURL ?: @""];
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
	[self updateSelectedNote];
}

- (void) updateSelectedNote
{
	if (self.isUpdatingNotesList) {
		return;
	}
	NSInteger row = self.tableView.selectedRow;
	MBNote* note = ((row >= 0) && (row < self.currentNotes.count)) ? self.currentNotes[row] : nil;
	if (note == self.selectedNote) {
		return;
	}

	[self syncFromTimer:nil];
	BOOL same_text = note.noteID && [self.selectedNote.noteID isEqualToNumber:note.noteID] && [note.text isEqualToString:self.selectedNote.text];
	self.selectedNote = note;
	if (!same_text) {
		[self setDetailText:note.text ?: @"" forNote:note];
	}
	[self setDetailBook:note.attachedBookISBN title:note.attachedBookTitle];
	[self updateDetailSharingFooter];
	[self setupMenuForNote:note];
}

#pragma mark -

- (NSUndoManager *) undoManagerForTextView:(NSTextView *)textView
{
	return self.textUndoManager;
}

- (void) textDidChange:(NSNotification *)notification
{
	if (self.selectedNote) {
		self.selectedNote.text = [self.detailTextView string];
		[self.editedNotes addObject:self.selectedNote];
		[self.failedNotes removeObject:self.selectedNote];
		if (![self.localNotes containsObject:self.selectedNote]) {
			[self.localNotes addObject:self.selectedNote];
		}
		[self reloadRowForNote:self.selectedNote onlyRecentNotes:YES];
	}
}

@end
