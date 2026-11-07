# Run with: ruby Tests/notes_deletion_test.rb
# Deliver real controller callbacks out of order without touching an account or the disk cache.
require 'tmpdir'

controller = File.read(File.expand_path('../Source/MBNotesController.m', __dir__))
names = %w[fetchNotesWithNotebookID cachedNotesWithNotebookID notesByExcludingDeletedNotes noteIDsFromNotes mergeNotes removeNotesFromArray deleteCachedNotesWithNotebookID notesArrayByIncludingNewNoteIfNeeded currentSelectedNoteID updateCurrentNotesForSearch updateNotesListWithArray deleteNote removeDeletedNoteWithID syncNote]
methods = controller.scan(/^- \([^\n]+\) (?:#{names.join('|')})\b[^;\n]*\n\{.*?^\}/m)
abort 'Missing Notes methods' unless methods.count == names.count + 2

source = <<~'OBJC'
	#import <Foundation/Foundation.h>
	static NSMutableArray* main_queue;
	#define RFDispatchMainAsync(...) [main_queue addObject:[(__VA_ARGS__) copy]]

	@interface MBNote : NSObject
	@property (strong) NSNumber* noteID;
	@property (strong) NSNumber* notebookID;
	@property (copy) NSString* text;
	@property (copy) NSString* sharedURL;
	@property (strong) NSDate* updatedAt;
	@property BOOL isEncrypted, isSharing, isUnsharing;
	@end
	@implementation MBNote
	+ (MBNote *) noteWithDictionary:(NSDictionary *)dictionary notebookID:(NSNumber *)notebookID secretKey:(NSString *)secretKey
	{
		MBNote* note = [MBNote new];
		note.noteID = dictionary[@"id"];
		note.text = dictionary[@"text"];
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
	- (NSArray *) notesWithNotebookID:(NSNumber *)notebookID { return cache.allValues; }
	- (void) saveNote:(MBNote *)note
	{
		cache[note.noteID] = note;
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
			if (![noteIDs containsObject:note_id]) {
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
	@interface RFClient : NSObject
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path { return [super init]; }
	- (instancetype) initWithFormat:(NSString *)format, ... { return [super init]; }
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler { [requests addObject:[handler copy]]; }
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler { [requests addObject:[handler copy]]; }
	- (void) deleteWithObject:(id)object completion:(void (^)(UUHttpResponse*))handler { [requests addObject:[handler copy]]; }
	@end

	@implementation NSError (TestNetworkMessage)
	- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response { return @"Request failed."; }
	@end
	static NSString* alert_title;
	@interface NSAlert : NSObject
	@end
	@implementation NSAlert
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler { alert_title = title; }
	@end

	@interface TestControl : NSObject
	@property (copy) NSString* stringValue;
	@property NSInteger selectedRow;
	@property BOOL enabled;
	@property (strong) TestControl* window;
	@end
	@implementation TestControl
	- (void) reloadData {}
	- (void) selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend {}
	- (void) makeFirstResponder:(id)responder {}
	@end
	@interface MBNotebook : NSObject
	@property (strong) NSNumber* notebookID;
	@end
	@implementation MBNotebook
	@end

	@interface TestController : NSObject
	@property BOOL isFetchingNotes, isPagingNotesInBackground, shouldStartNewNoteAfterFetch;
	@property NSInteger notesFetchRequestID;
	@property (strong) NSMutableSet* editedNotes;
	@property (strong) NSMutableSet* deletingNoteIDs;
	@property (strong) NSMutableSet* deletedNoteIDs;
	@property (strong) NSMutableSet* noteIDsChangedWhilePaging;
	@property (strong) NSMutableArray* audioNotesCreatedWhileFetching;
	@property (strong) MBNote* noteCreatedWhileFetching;
	@property (strong) MBNote* selectedNote;
	@property (strong) MBNotebook* currentNotebook;
	@property (strong) NSArray* notebooks;
	@property (strong) NSArray* allNotes;
	@property (strong) NSArray* currentNotes;
	@property (strong) TestControl* tableView;
	@property (strong) TestControl* searchField;
	@property (strong) TestControl* notebooksPopup;
	@property (strong) TestControl* view;
	@property (strong) id detailTextView;
	@property (copy) NSString* secretKey;
	@end
	@implementation TestController
	- (void) startNotesProgress {}
	- (void) stopNotesProgress {}
	- (void) startNewNoteAfterFirstBatchIfNeeded {}
	- (void) updateDetailSharingFooter {}
	- (void) setupMenuForNote:(MBNote *)note {}
	- (void) deselectAll { self.selectedNote = nil; self.tableView.selectedRow = -1; }
	- (void) runSearch:(NSString *)search { [self updateCurrentNotesForSearch:search preservingSelectedNoteID:self.selectedNote.noteID]; }
	- (void) restoreSelectionWithNoteID:(NSNumber *)noteID focusDetail:(BOOL)focus {}
	- (void) reloadRowForNote:(MBNote *)note onlyRecentNotes:(BOOL)recent {}
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

	int main(void)
	{
		@autoreleasepool {
			main_queue = [NSMutableArray array];
			requests = [NSMutableArray array];
			cache_writes = [NSMutableSet set];
			NSDictionary* deleted_item = @{ @"id": @1, @"text": @"Search match to delete" };
			NSDictionary* kept_item = @{ @"id": @2, @"text": @"Search match to keep" };
			MBNote* deleted = [MBNote noteWithDictionary:deleted_item notebookID:@3 secretKey:nil];
			MBNote* kept = [MBNote noteWithDictionary:kept_item notebookID:@3 secretKey:nil];
			cache = [@{ @1: deleted, @2: kept } mutableCopy];
			TestController* controller = [TestController new];
			controller.currentNotebook = [MBNotebook new];
			controller.currentNotebook.notebookID = @3;
			controller.secretKey = @"test-key";
			controller.tableView = [TestControl new];
			controller.tableView.selectedRow = -1;
			controller.searchField = [TestControl new];
			controller.searchField.stringValue = @"search";
			controller.selectedNote = kept;
			controller.editedNotes = [NSMutableSet setWithObjects:kept, deleted, nil];
			controller.deletingNoteIDs = [NSMutableSet set];
			controller.deletedNoteIDs = [NSMutableSet set];
			controller.noteIDsChangedWhilePaging = [NSMutableSet set];
			controller.audioNotesCreatedWhileFetching = [NSMutableArray array];
			[controller fetchNotesWithNotebookID:@3 completion:nil];
			[controller syncNote:deleted completion:^{ NSCAssert(NO, @"A late autosave must not call its success handler"); }];

			[controller deleteNote:deleted];
			[controller deleteNote:deleted];
			NSCAssert(requests.count == 3, @"Only one DELETE while the first request is pending");
			NSError* lost_connection = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
			respond(2, nil, lost_connection);
			applyResponses();
			NSCAssert(cache[@1] && [controller.editedNotes containsObject:deleted] && controller.currentNotes.count == 2, @"A failed delete keeps the note and its edit");
			NSCAssert([alert_title isEqual:@"Error Deleting Note"], @"Report a failed delete");

			[controller deleteNote:deleted];
			respond(3, @{}, nil);
			NSDictionary* stale_page = @{ @"items": @[deleted_item, kept_item] };
			respond(0, stale_page, nil);
			respond(1, @{ @"id": @1 }, nil);
			applyResponses();
			NSCAssert(!cache[@1] && cache[@2], @"A late page and autosave must not restore a confirmed deletion");
			NSCAssert(controller.editedNotes.count == 1 && [controller.editedNotes containsObject:kept], @"Discard only the deleted note's queued edits");
			NSCAssert(controller.currentNotes.count == 1 && controller.selectedNote == kept, @"Keep the search and unrelated selection");
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
			controller.noteCreatedWhileFetching = pending;
			respond(5, @{ @"items": @[kept_item] }, nil);
			applyResponses();
			NSCAssert(controller.currentNotes.count == 2 && [controller.currentNotes containsObject:pending], @"Preserve the selected new note while it has no server ID");
			NSLog(@"Notes deletion tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-notes-deletion-tests-') do |directory|
	path = File.join(directory, 'notes.m')
	binary = File.join(directory, 'notes')
	File.write(path, source.sub('__METHODS__') { methods.join("\n") })
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Notes deletion tests failed' unless system(binary)
end
