# Run with: ruby Tests/notes_deletion_test.rb
# Exercise creation, editing, refresh, and deletion with reordered real controller callbacks.
# The network, disk cache, and UI are isolated from the running app.
require 'tmpdir'

controller = File.read(File.expand_path('../Source/MBNotesController.m', __dir__))
names = %w[updateSelectedNote shareOrUnshare fetchNotes fetchNotebooksWithCompletion reloadRowForNote fetchNotesWithNotebookID cachedNotesWithNotebookID notesByExcludingDeletedNotes noteIDsFromNotes mergeNotes removeNotesFromArray deleteCachedNotesWithNotebookID notesArrayByIncludingLocalNotes currentSelectedNoteID updateCurrentNotesForSearch updateNotesListWithArray deleteNote removeDeletedNoteWithID syncNote syncFromTimer findNote createNewNote startNewNote tableViewSelectionDidChange textDidChange]
methods = controller.scan(/^- \([^\n]+\) (?:#{names.join('|')})\b[^;\n]*\n\{.*?^\}/m)
abort 'Missing Notes methods' unless methods.count == names.count + 2

note_source = File.read(File.expand_path('../Source/MBNote.m', __dir__))
copy_method = note_source[/^- \(id\) copyWithZone:.*?^\}/m]
source = <<~'OBJC'
	#import <Foundation/Foundation.h>
	static NSMutableArray* main_queue;
	#define RFDispatchMainAsync(...) [main_queue addObject:[(__VA_ARGS__) copy]]

	@interface MBNote : NSObject <NSCopying>
	@property (strong) NSNumber* noteID;
	@property (strong) NSNumber* notebookID;
	@property (copy) NSString* text;
	@property (copy) NSString* sharedURL;
	@property (strong) NSDate* updatedAt;
	@property (strong) NSDate* createdAt;
	@property (copy) NSString* attachedBookISBN;
	@property (copy) NSString* attachedBookTitle;
	@property BOOL isEncrypted, isShared, isSharing, isUnsharing;
	@end
	@implementation MBNote
	__COPY_METHOD__
	+ (MBNote *) noteWithDictionary:(NSDictionary *)dictionary notebookID:(NSNumber *)notebookID secretKey:(NSString *)secretKey
	{
		MBNote* note = [MBNote new];
		note.noteID = dictionary[@"id"];
		note.text = dictionary[@"text"];
		note.createdAt = [NSDate date];
		note.notebookID = notebookID;
		return note;
	}
	+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)key { return text; }
	@end

	static NSMutableDictionary* cache;
	static NSMutableSet* cache_writes;
	@interface MBNotesDatabase : NSObject
	@end
	@implementation MBNotesDatabase
	+ (BOOL) databaseExists { return YES; }
	- (NSArray *) notesWithNotebookID:(NSNumber *)notebookID
	{
		NSMutableArray* result = [NSMutableArray array];
		for (NSNumber* note_id in [cache.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
			MBNote* note = cache[note_id];
			if ([note.notebookID isEqual:notebookID]) { [result addObject:[note copy]]; }
		}
		return result;
	}
	- (void) saveNote:(MBNote *)note
	{
		cache[note.noteID] = [note copy];
		[cache_writes addObject:note.noteID];
	}
	- (void) saveNotes:(NSArray *)notes
	{
		for (MBNote* note in notes) {
			[self saveNote:note];
		}
	}
	- (void) deleteNoteWithID:(NSNumber *)noteID { [cache removeObjectForKey:noteID]; }
	- (void) deleteNotesWithNotebookID:(NSNumber *)notebookID notInNoteIDs:(NSSet *)noteIDs
	{
		for (NSNumber* note_id in cache.allKeys) {
			if ([((MBNote *)cache[note_id]).notebookID isEqual:notebookID] && ![noteIDs containsObject:note_id]) {
				[self deleteNoteWithID:note_id];
			}
		}
	}
	- (void) close {}
	@end

	@interface UUHttpResponse : NSObject
	@property (strong) id parsedResponse;
	@property (strong) NSHTTPURLResponse* httpResponse;
	@property (strong) NSError* httpError;
	@end
	@implementation UUHttpResponse
	@end

	static NSMutableArray* requests;
	static NSMutableArray* request_details;
	@interface RFClient : NSObject
	@property (copy) NSString* path;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path { self = [super init]; self.path = path; return self; }
	- (instancetype) initWithFormat:(NSString *)format, ... { self = [super init]; self.path = format; return self; }
	- (void) request:(NSString *)method args:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		[request_details addObject:@{ @"method": method, @"path": self.path, @"args": [args copy] ?: @{} }];
		[requests addObject:[handler copy]];
	}
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler { [self request:@"GET" args:args completion:handler]; }
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler { [self request:@"POST" args:params completion:handler]; }
	- (void) deleteWithObject:(id)object completion:(void (^)(UUHttpResponse*))handler { [self request:@"DELETE" args:nil completion:handler]; }
	@end

	@implementation NSError (TestNetworkMessage)
	- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response { return @"Request failed."; }
	@end
	static NSString* alert_title;
	typedef NSInteger NSModalResponse;
	static const NSModalResponse NSAlertFirstButtonReturn = 1000;
	static void (^alert_completion)(NSModalResponse);
	@interface NSAlert : NSObject
	@end
	@implementation NSAlert
	+ (void) rf_showTwoButtonAlert:(NSString *)title message:(NSString *)message okButton:(NSString *)ok cancelButton:(NSString *)cancel completionHandler:(void (^)(NSModalResponse))handler { alert_title = title; alert_completion = [handler copy]; }
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler { alert_title = title; }
	@end

	static NSString* const kCurrentNotebookIDPrefKey = @"notes-sync-test-notebook";
	@interface NSColor : NSObject
	@end
	@implementation NSColor
	+ (NSColor *) mb_colorFromString:(NSString *)color { return nil; }
	@end
	@interface NSMenuItem : NSObject
	@property NSInteger tag;
	@end
	@implementation NSMenuItem
	- (instancetype) initWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)key { return [super init]; }
	@end
	@interface MBNoteCell : NSObject
	@end
	@implementation MBNoteCell
	- (void) setupWithNote:(MBNote *)note {}
	@end
	@interface TestControl : NSObject
	@property (weak) id delegate;
	@property NSInteger focusCount;
	@property (strong) TestControl* menu;
	@property (copy) NSString* stringValue;
	@property NSInteger selectedRow;
	@property BOOL enabled;
	@property (strong) TestControl* window;
	@end
	@implementation TestControl
	- (void) notifySelection
	{
		[self.delegate performSelector:@selector(tableViewSelectionDidChange:) withObject:nil];
	}
	- (void) reloadData { self.selectedRow = -1; [self notifySelection]; }
	- (void) selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend { self.selectedRow = indexes.firstIndex; [self notifySelection]; }
	- (void) deselectAll:(id)sender { self.selectedRow = -1; [self notifySelection]; }
	- (void) makeFirstResponder:(id)responder { self.focusCount++; }
	- (void) scrollRowToVisible:(NSInteger)row {}
	- (id) rowViewAtRow:(NSInteger)row makeIfNecessary:(BOOL)create { return nil; }
	- (void) removeAllItems {}
	- (void) addItem:(NSMenuItem *)item {}
	- (void) selectItemWithTag:(NSInteger)tag {}
	- (NSString *) string { return self.stringValue; }
	@end
	@interface MBNotebook : NSObject
	@property (copy) NSString* name;
	@property (strong) NSColor* lightColor;
	@property (strong) NSColor* darkColor;
	@property (strong) NSNumber* notebookID;
	@end
	@implementation MBNotebook
	@end

	@interface TestController : NSObject
	@property BOOL isFetchingNotes, isUpdatingNotesList;
	@property NSInteger editorResets;
	@property NSInteger notesFetchRequestID;
	@property (strong) NSMutableSet* editedNotes;
	@property (strong) NSMutableSet* deletingNoteIDs;
	@property (strong) NSMutableSet* deletedNoteIDs;
	@property (strong) NSMutableSet* syncingNotes;
	@property (strong) NSMutableSet* failedNotes;
	@property (strong) NSMutableArray* localNotes;
	@property (strong) NSArray* pendingNotesList;
	@property (strong) NSMapTable* noteSyncCompletions;
	@property (strong) MBNote* selectedNote;
	@property (strong) MBNotebook* currentNotebook;
	@property (strong) NSArray* notebooks;
	@property (strong) NSArray* allNotes;
	@property (strong) NSArray* currentNotes;
	@property (strong) TestControl* tableView;
	@property (strong) TestControl* searchField;
	@property (strong) TestControl* notebooksPopup;
	@property (strong) TestControl* view;
	@property (strong) TestControl* detailTextView;
	@property (copy) NSString* secretKey;
	@end
	@implementation TestController
	- (void) startNotesProgress {}
	- (void) stopNotesProgress {}
	- (void) updateProgressSpinner {}
	- (void) saveNotesToDisk {}
	- (void) updateDetailsColor {}
	- (void) setDetailText:(NSString *)text forNote:(MBNote *)note { self.detailTextView.stringValue = text; self.editorResets++; }
	- (void) setDetailBook:(NSString *)isbn title:(NSString *)title {}
	- (void) updateDetailSharingFooter {}
	- (void) setupMenuForNote:(MBNote *)note {}
	- (void) deselectAll { self.selectedNote = nil; self.tableView.selectedRow = -1; }
	- (void) runSearch:(NSString *)search { [self updateCurrentNotesForSearch:search preservingSelectedNoteID:self.selectedNote.noteID]; }
	- (void) finishInitialNotesLoadWithCompletion:(void (^)(void))handler { if (handler) { handler(); } }
	__METHODS__
	@end

	static void respond(NSUInteger index, id result, NSError* error)
	{
		UUHttpResponse* response = [UUHttpResponse new];
		response.parsedResponse = result;
		response.httpError = error;
		void (^handler)(UUHttpResponse*) = requests[index];
		handler(response);
	}

	static void applyResponses(void)
	{
		while (main_queue.count > 0) {
			void (^block)(void) = main_queue.firstObject;
			[main_queue removeObjectAtIndex:0];
			block();
		}
	}

	static TestController* newController(void)
	{
		TestController* controller = [TestController new];
		controller.currentNotebook = [MBNotebook new];
		controller.currentNotebook.notebookID = @3;
		controller.secretKey = @"test-key";
		controller.tableView = [TestControl new];
		controller.tableView.delegate = controller;
		controller.tableView.selectedRow = -1;
		controller.searchField = [TestControl new];
		controller.searchField.stringValue = @"";
		controller.detailTextView = [TestControl new];
		controller.view = [TestControl new];
		controller.view.window = [TestControl new];
		controller.editedNotes = [NSMutableSet set];
		controller.deletingNoteIDs = [NSMutableSet set];
		controller.deletedNoteIDs = [NSMutableSet set];
		controller.syncingNotes = [NSMutableSet set];
		controller.failedNotes = [NSMutableSet set];
		controller.localNotes = [NSMutableArray array];
		controller.noteSyncCompletions = [NSMapTable strongToStrongObjectsMapTable];
		return controller;
	}

	static void reset(void)
	{
		main_queue = [NSMutableArray array];
		requests = [NSMutableArray array];
		request_details = [NSMutableArray array];
		cache_writes = [NSMutableSet set];
		cache = [NSMutableDictionary dictionary];
		alert_title = nil;
		alert_completion = nil;
	}

	static void editText(TestController* controller, NSString* text)
	{
		controller.detailTextView.stringValue = text;
		[controller textDidChange:nil];
	}

	static NSDictionary* arguments(NSUInteger index)
	{
		return request_details[index][@"args"];
	}

	int main(void)
	{
		@autoreleasepool {
			reset();
			NSDictionary* deleted_item = @{ @"id": @1, @"text": @"Search match to delete" };
			NSDictionary* kept_item = @{ @"id": @2, @"text": @"Search match to keep" };
			MBNote* deleted = [MBNote noteWithDictionary:deleted_item notebookID:@3 secretKey:nil];
			MBNote* kept = [MBNote noteWithDictionary:kept_item notebookID:@3 secretKey:nil];
			cache = [@{ @1: deleted, @2: kept } mutableCopy];
			TestController* controller = newController();
			controller.searchField.stringValue = @"search";
			controller.selectedNote = kept;
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			kept = controller.selectedNote;
			[controller.editedNotes addObject:kept];
			[controller.localNotes addObject:kept];
			[controller syncNote:deleted completion:^{ NSCAssert(NO, @"A late autosave must not call its success handler"); }];

			[controller deleteNote:deleted];
			[controller deleteNote:deleted];
			NSCAssert(requests.count == 3, @"Only one DELETE while the first request is pending");
			NSError* lost_connection = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
			respond(2, nil, lost_connection);
			applyResponses();
			NSCAssert(cache[@1] && [controller.syncingNotes containsObject:deleted] && controller.currentNotes.count == 2, @"A failed delete keeps the note and its edit");
			NSCAssert([alert_title isEqual:@"Error Deleting Note"], @"Report a failed delete");

			[controller deleteNote:deleted];
			respond(3, @{}, nil);
			NSDictionary* stale_page = @{ @"items": @[deleted_item, kept_item] };
			respond(0, stale_page, nil);
			respond(1, @{ @"id": @1 }, nil);
			applyResponses();
			NSCAssert(!cache[@1] && cache[@2], @"A late page and autosave must not restore a confirmed deletion");
			NSCAssert(controller.editedNotes.count == 1 && [controller.editedNotes containsObject:kept], @"Discard only the deleted note's queued edits");
			NSCAssert(controller.currentNotes.count == 1 && [controller.selectedNote.noteID isEqual:kept.noteID], @"Keep the search and unrelated selection");
			NSCAssert(requests.count == 5, @"Refresh after the confirmed deletion");

			respond(4, stale_page, nil);
			applyResponses();
			NSCAssert(![cache_writes containsObject:@1] && cache[@2], @"Even a stale page from the new refresh cannot cache the deleted note");
			NSCAssert(controller.currentNotes.count == 1 && [[controller.currentNotes.firstObject noteID] isEqualToNumber:kept.noteID], @"Refresh only the surviving note");
			[controller syncNote:deleted completion:nil];
			NSCAssert(requests.count == 5, @"Do not autosave a deleted note");

			controller.searchField.stringValue = @"";
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			MBNote* pending = [MBNote new];
			pending.notebookID = @3;
			controller.selectedNote = pending;
			[controller.localNotes addObject:pending];
			respond(5, @{ @"items": @[kept_item] }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 2 && [controller.currentNotes containsObject:pending], @"Preserve the selected new note while it has no server ID");
			// First launch: New Note is editable even before the notebook list arrives.
			reset();
			controller = newController();
			controller.currentNotebook = nil;
			[controller fetchNotes];
			[controller startNewNote];
			NSCAssert(requests.count == 1, @"Use the existing initial notebook request");
			NSCAssert(controller.selectedNote && !controller.selectedNote.notebookID, @"Create a local note before notebooks are known");
			editText(controller, @"Typing while notebooks still load");
			[controller syncFromTimer:nil];
			NSCAssert(requests.count == 1, @"Wait for a notebook before POSTing the editable local note");
			respond(0, @{ @"items": @[@{ @"id": @3, @"title": @"Notes" }] }, nil);
			NSCAssert(!controller.currentNotebook, @"Notebook selection changes on the main queue only");
			applyResponses();
			MBNote* first = controller.selectedNote;
			NSCAssert(first && !first.noteID && controller.currentNotes.firstObject == first, @"Editor is attached before creation finishes");
			NSCAssert(requests.count == 3 && [request_details[1][@"method"] isEqual:@"POST"], @"Create while the first notes page is loading");
			editText(controller, @"Typing before the server assigns an ID");
			NSInteger resets = controller.editorResets;
			NSInteger focuses = controller.view.window.focusCount;
			[controller syncFromTimer:nil];
			[controller syncFromTimer:nil];
			NSCAssert(requests.count == 3, @"Timers cannot POST a second new note while creation is pending");
			respond(2, @{ @"items": @[] }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 1 && controller.selectedNote == first, @"An empty initial sync preserves the unsaved note");
			NSCAssert(controller.editorResets == resets && controller.view.window.focusCount == focuses, @"Refresh must preserve typing, undo, and focus");
			respond(1, @{ @"id": @100 }, nil);
			applyResponses();
			NSCAssert(requests.count == 4 && [arguments(3)[@"id"] isEqual:@100] && [arguments(3)[@"text"] isEqual:first.text], @"Typing follows creation as an update to its assigned ID");
			NSCAssert([((MBNote *)cache[@100]).text isEqual:@"Typing while notebooks still load"], @"Do not cache typing that has not been acknowledged yet");
			editText(controller, @"Latest typing while the first update is in flight");
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			NSCAssert(controller.selectedNote == first && controller.editorResets == resets, @"Cache loading cannot replace a live edit with its saved snapshot");
			respond(4, @{ @"items": @[@{ @"id": @100, @"text": @"" }] }, nil);
			applyResponses();
			NSCAssert(controller.selectedNote == first && [first.text isEqual:controller.detailTextView.stringValue], @"Stale server text cannot detach or overwrite the editor");
			respond(3, @{ @"id": @100 }, nil);
			applyResponses();
			NSCAssert(requests.count == 6 && [arguments(5)[@"id"] isEqual:@100] && [arguments(5)[@"text"] isEqual:first.text], @"Send the most recent typing after the prior update completes");
			respond(5, @{ @"id": @100 }, nil);
			applyResponses();
			NSCAssert([((MBNote *)cache[@100]).text isEqual:first.text] && controller.editedNotes.count == 0 && controller.syncingNotes.count == 0, @"Final acknowledged text is cached with no outstanding saves");
			NSCAssert(controller.editorResets == resets && controller.view.window.focusCount == focuses, @"Save responses must not reset or refocus the editor");

			// Clean refreshes still accept server changes, without resetting identical text.
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			respond(6, @{ @"items": @[@{ @"id": @100, @"text": first.text }] }, nil);
			applyResponses();
			NSCAssert(controller.editorResets == resets, @"An unchanged clean refresh preserves undo");
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			respond(7, @{ @"items": @[@{ @"id": @100, @"text": @"Changed on another device" }] }, nil);
			applyResponses();
			NSCAssert([controller.detailTextView.stringValue isEqual:@"Changed on another device"], @"A clean note can receive remote changes");
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			[controller.tableView deselectAll:nil];
			respond(8, @{ @"items": @[@{ @"id": @100, @"text": first.text }] }, nil);
			applyResponses();
			NSCAssert(!controller.selectedNote && controller.tableView.selectedRow == -1, @"A stale captured selection must not undo deliberate deselection");

			// Multiple new notes during pagination, with create responses in reverse order.
			reset();
			controller = newController();
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			NSMutableArray* page = [NSMutableArray array];
			for (NSInteger i = 1; i <= 100; i++) {
				[page addObject:@{ @"id": @(i), @"text": @"Existing note" }];
			}
			respond(0, @{ @"items": page }, nil);
			applyResponses();
			controller.searchField.stringValue = @"old search";
			[controller startNewNote];
			first = controller.selectedNote;
			editText(controller, @"First new note");
			[controller startNewNote];
			MBNote* second = controller.selectedNote;
			editText(controller, @"Second new note");
			NSCAssert(first != second && controller.searchField.stringValue.length == 0 && requests.count == 4, @"Each deliberate New Note gets one create and clears the active search");
			resets = controller.editorResets;
			focuses = controller.view.window.focusCount;
			respond(3, @{ @"id": @102 }, nil);
			applyResponses();
			respond(2, @{ @"id": @101 }, nil);
			applyResponses();
			respond(1, @{ @"items": @[] }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 102 && controller.selectedNote == second, @"The final page preserves every locally created note and the current selection");
			NSCAssert(cache[@101] && cache[@102], @"Pruning an older server list cannot delete newly saved notes from the cache");
			NSCAssert(controller.editorResets == resets && controller.view.window.focusCount == focuses, @"Another note's save must not steal the current editor");
			NSCAssert([arguments(4)[@"id"] isEqual:@102] && [arguments(5)[@"id"] isEqual:@101], @"Each pending note updates its own server ID");
			respond(4, @{ @"id": @102 }, nil);
			respond(5, @{ @"id": @101 }, nil);
			applyResponses();

			// Switching notebooks while creating, then returning before the update finishes.
			reset();
			controller = newController();
			[controller startNewNote];
			first = controller.selectedNote;
			editText(controller, @"Keep this text in notebook 3");
			[controller.tableView deselectAll:nil];
			controller.currentNotebook.notebookID = @4;
			[controller fetchNotesWithNotebookID:@4 completion:nil];
			respond(0, @{ @"id": @201 }, nil);
			applyResponses();
			respond(1, @{ @"items": @[] }, nil);
			applyResponses();
			NSCAssert(!controller.selectedNote && controller.currentNotes.count == 0, @"A save from the old notebook cannot select or insert into the new one");
			controller.currentNotebook.notebookID = @3;
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			NSCAssert(controller.currentNotes.count == 1 && controller.currentNotes.firstObject == first, @"Returning to a notebook preserves its in-flight edit");
			[controller.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
			respond(3, @{ @"items": @[] }, nil);
			respond(2, @{ @"id": @201 }, nil);
			applyResponses();
			NSCAssert(controller.selectedNote == first && [controller.detailTextView.stringValue isEqual:first.text], @"The editor reconnects to the same pending note after a notebook switch");

			// A list response can contain the new server note before POST returns its ID.
			reset();
			controller = newController();
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			[controller startNewNote];
			first = controller.selectedNote;
			editText(controller, @"Local typing");
			respond(0, @{ @"items": @[@{ @"id": @301, @"text": @"" }] }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 1 && controller.currentNotes.firstObject == first, @"Do not show a second editable row while its server identity is still unknown");
			respond(1, @{ @"id": @301 }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 1 && controller.currentNotes.firstObject == first && controller.selectedNote == first, @"Reconcile a server echo with the local note when its ID arrives");
			NSCAssert(requests.count == 3 && [arguments(2)[@"id"] isEqual:@301], @"The server echo cannot create another note");
			respond(2, @{ @"id": @301 }, nil);
			applyResponses();

			// Failed or malformed creates do not run success handlers or retry every timer tick.
			reset();
			controller = newController();
			[controller startNewNote];
			first = controller.selectedNote;
			editText(controller, @"Retain this after an error");
			__block BOOL did_complete = NO;
			[controller syncNote:first completion:^{ did_complete = YES; }];
			respond(0, @{ @"error": @"Bad gateway" }, lost_connection);
			applyResponses();
			[controller syncFromTimer:nil];
			[controller syncFromTimer:nil];
			NSCAssert(!did_complete && !first.noteID && requests.count == 1 && cache.count == 0, @"A failed create neither succeeds locally nor creates a retry storm");
			NSCAssert([controller.detailTextView.stringValue isEqual:first.text] && [alert_title isEqual:@"Error Saving Note"], @"Keep the editable text and explain the failed save");
			alert_completion(NSAlertFirstButtonReturn);
			respond(1, @{ @"id": [NSNull null] }, nil);
			applyResponses();
			NSCAssert(!first.noteID && !did_complete, @"Reject a malformed success response");
			alert_completion(NSAlertFirstButtonReturn);
			respond(2, @{ @"id": @401 }, nil);
			applyResponses();
			NSCAssert(did_complete && [((MBNote *)cache[@401]).text isEqual:first.text], @"Explicit retry saves the current text and completes queued work");

			// Sharing is queued behind autosave and completes on its original note.
			reset();
			controller = newController();
			[controller startNewNote];
			first = controller.selectedNote;
			respond(0, @{ @"id": @501 }, nil);
			applyResponses();
			editText(controller, @"Text before sharing");
			[controller syncFromTimer:nil];
			[controller shareOrUnshare:nil];
			NSCAssert(requests.count == 2, @"Sharing must wait for the current autosave");
			respond(1, @{ @"id": @501, @"_microblog": @{ @"is_shared": @NO } }, nil);
			applyResponses();
			NSCAssert([arguments(2)[@"id"] isEqual:@501] && [arguments(2)[@"is_sharing"] boolValue] && ![arguments(2)[@"is_encrypted"] boolValue], @"Send the queued sharing request using the existing ID");
			editText(controller, @"Text edited while sharing");
			[controller startNewNote];
			second = controller.selectedNote;
			NSDictionary* shared_result = @{ @"id": @501, @"_microblog": @{ @"is_shared": @YES, @"shared_url": @"https://example.com/note" } };
			respond(2, shared_result, nil);
			applyResponses();
			NSCAssert(first.isShared && !first.isSharing && !second.isShared && controller.selectedNote == second, @"Sharing completion cannot modify a different selected note");
			NSCAssert([arguments(4)[@"id"] isEqual:@501] && !arguments(4)[@"is_sharing"] && [arguments(4)[@"text"] isEqual:first.text], @"Follow-up typing must not repeat sharing and regenerate its URL");
			respond(3, @{ @"id": @502 }, nil);
			respond(4, shared_result, nil);
			applyResponses();
			NSCAssert([((MBNote *)cache[@501]).text isEqual:first.text] && ((MBNote *)cache[@501]).isShared, @"Cache the confirmed shared text");

			// A refresh started after an older one ignores its late pages.
			reset();
			controller = newController();
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			[controller startNewNote];
			first = controller.selectedNote;
			editText(controller, @"Newest fetch wins");
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			respond(2, @{ @"items": @[] }, nil);
			respond(0, @{ @"items": page }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 1 && controller.selectedNote == first && cache.count == 0, @"An obsolete request cannot change the list or cache");
			NSLog(@"Notes sync and deletion tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-notes-deletion-tests-') do |directory|
	path = File.join(directory, 'notes.m')
	binary = File.join(directory, 'notes')
	File.write(path, source.sub('__METHODS__') { methods.join("\n") }.sub('__COPY_METHOD__') { copy_method })
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Notes deletion tests failed' unless system(binary)
end
