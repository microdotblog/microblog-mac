//
//  MBBooksWindowController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBooksWindowController.h"

#import "RFBookshelf.h"
#import "MBBook.h"
#import "MBNotebook.h"
#import "MBBookCell.h"
#import "MBBookNoteController.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "NSString+Extras.h"
#import "NSColor+Extras.h"

@implementation MBBooksWindowController

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf
{
	self = [super initWithWindowNibName:@"BooksWindow"];
	if (self) {
		self.bookshelf = bookshelf;
		self.allBooks = @[];
		self.currentBooks = @[];
		self.coversQueue = [NSMutableSet set];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTitle];
	[self setupTable];
	[self setupNotifications];
	[self setupBooksCount];
	[self setupBrowser];
	
	[self fetchBooks];
	[self fetchBookshelves];
}

- (void) setupTitle
{
	self.window.title = self.bookshelf.title;
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BookCell" bundle:nil] forIdentifier:@"BookCell"];
	[self.tableView setTarget:self];
	self.window.initialFirstResponder = self.tableView;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addBookNotification:) name:kAddBookNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addNoteNotification:) name:kAddNoteNotification object:nil];
}

- (void) setupBooksCount
{
	if ([self isSearch]) {
		self.booksCountField.hidden = YES;
	}
	else {
		NSString* s;
		if (self.allBooks.count == 0) {
			s = @"";
		}
		else if (self.allBooks.count == 1) {
			s = @"1 book";
		}
		else {
			s = [NSString stringWithFormat:@"%lu books", (unsigned long)self.allBooks.count];
		}
		self.booksCountField.stringValue = s;
		self.booksCountField.hidden = NO;
	}
}

- (void) setupBrowser
{
	self.browserMenuItem.title = [NSString mb_openInBrowserString];
}

- (void) setupBookshelvesMenu
{
	for (RFBookshelf* shelf in self.bookshelves) {
		if (![shelf isLibrary]) {
			NSMenuItem* new_item = [self.contextMenu addItemWithTitle:shelf.title action:@selector(assignToBookshelf:) keyEquivalent:@""];
			new_item.representedObject = shelf;
		}
	}
	
	if ([self.bookshelf isLibrary]) {
		NSMenu* menu = [self.deleteMenuItem menu];
		[menu removeItem:self.deleteMenuItem];
		[menu removeItem:self.deleteSeparatorItem];
	}
}

#pragma mark -

- (void) fetchBooks
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:[NSString stringWithFormat:@"/books/bookshelves/%@", self.bookshelf.bookshelfID]];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_books = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBBook* b = [[MBBook alloc] init];
				b.bookID = [item objectForKey:@"id"];
				b.title = [item objectForKey:@"title"];
				b.coverURL = [item objectForKey:@"image"];
				b.isbn = [[item objectForKey:@"_microblog"] objectForKey:@"isbn"];

				NSMutableArray* author_names = [NSMutableArray array];
				for (NSDictionary* info in [item objectForKey:@"authors"]) {
					[author_names addObject:[info objectForKey:@"name"]];
				}
				b.authors = author_names;

				[new_books addObject:b];
			}
			
			RFDispatchMainAsync (^{
				if (![RFBookshelf isSameBooks:self.allBooks asBooks:new_books]) {
					self.allBooks = new_books;
					self.currentBooks = new_books;
					self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
					[self.tableView reloadData];
					[self setupBooksCount];
				}
				
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) fetchBooksForSearch:(NSString *)search
{
	self.booksCountField.hidden = YES;
	[self.progressSpinner startAnimation:nil];

	NSString* url = @"https://www.googleapis.com/books/v1/volumes";
	
	NSDictionary* args = @{
		@"q": search
	};
	
	UUHttpRequest* request = [UUHttpRequest getRequest:url queryArguments:args];
	[UUHttpSession executeRequest:request completionHandler:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_books = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* volume_info = [item objectForKey:@"volumeInfo"];

				NSString* title = [volume_info objectForKey:@"title"];
				NSArray* authors = [volume_info objectForKey:@"authors"];
				if (authors.count == 0) {
					authors = @[];
				}
				NSString* description = [volume_info objectForKey:@"description"];

				NSString* cover_url = @"";
				if ([volume_info objectForKey:@"imageLinks"] != nil) {
					cover_url = [[volume_info objectForKey:@"imageLinks"] objectForKey:@"smallThumbnail"];
					if ([cover_url containsString:@"http://"]) {
						cover_url = [cover_url stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
					}
				}

				NSString* best_isbn = @"";
				NSMutableArray* isbns = [volume_info objectForKey:@"industryIdentifiers"];
				if (isbns != nil) {
					for (NSDictionary* isbn in isbns) {
						if ([[isbn objectForKey:@"type"] isEqualToString:@"ISBN_13"]) {
							best_isbn = [isbn objectForKey:@"identifier"];
							break;
						}
						else if ([[isbn objectForKey:@"type"] isEqualToString:@"ISBN_10"]) {
							best_isbn = [isbn objectForKey:@"identifier"];
						}
					}
				}

				MBBook* b = [[MBBook alloc] init];
				b.title = title;
				b.authors = authors;
				b.coverURL = cover_url;
				b.isbn = best_isbn;
				b.bookDescription = description;

				[new_books addObject:b];
			}

			RFDispatchMainAsync (^{
				self.currentBooks = new_books;
				[self.progressSpinner stopAnimation:nil];
				self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
				[self.tableView reloadData];
			});
		}
	}];
}

- (void) fetchBookshelves
{
	self.bookshelves = @[];

	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/books/bookshelves"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_bookshelves = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFBookshelf* shelf = [[RFBookshelf alloc] init];
				shelf.bookshelfID = [item objectForKey:@"id"];
				shelf.title = [item objectForKey:@"title"];
				shelf.booksCount = [[item objectForKey:@"_microblog"] objectForKey:@"books_count"];
				shelf.type = [[item objectForKey:@"_microblog"] objectForKey:@"type"];

				[new_bookshelves addObject:shelf];
			}
			
			RFDispatchMainAsync (^{
				self.bookshelves = new_bookshelves;
				[self setupBookshelvesMenu];
			});
		}
	}];
}

- (void) addBook:(MBBook *)book toBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* params = @{
		@"title": book.title,
		@"author": [book.authors firstObject],
		@"isbn": book.isbn,
		@"cover_url": book.coverURL,
		@"bookshelf_id": bookshelf.bookshelfID
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/books"];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self.searchField setStringValue:@""];
				[self fetchBooks];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasAddedNotification object:self userInfo:@{ kBookWasAddedBookshelfKey: bookshelf }];
			});
		}
	}];
}

- (void) removeBook:(MBBook *)book fromBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/books/bookshelves/%@/remove/%@", bookshelf.bookshelfID, book.bookID];
	[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self fetchBooks];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasRemovedNotification object:self userInfo:@{ kBookWasRemovedBookshelfKey: bookshelf }];
			});
		}
	}];
}

- (void) assignBook:(MBBook *)book toBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* params = @{
		@"book_id": book.bookID
	};
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/books/bookshelves/%@/assign", bookshelf.bookshelfID];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self fetchBooks];

				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasAssignedNotification object:self userInfo:@{ kBookWasAssignedBookshelfKey: bookshelf }];
			});
		}
	}];
}

- (BOOL) isSearch
{
	return [[self.searchField stringValue] length] > 0;
}

- (void) downloadCoverForBook:(MBBook *)book
{
	[self.coversQueue addObject:book];
	if (self.coversTimer == nil) {
		// timer to check for book covers to download, max 4 at a time
		self.coversTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
			if (self.coverDownloadsCount < 4) {
				[self checkCovers];
			}
		}];
	}
}

- (void) checkCovers
{
	MBBook* b = [self.coversQueue anyObject];
	if (b) {
		self.coverDownloadsCount++;
		[self.coversQueue removeObject:b];
		
		NSImage* cached_img = [b cachedCover];
		if (cached_img) {
			b.coverImage = cached_img;
			self.coverDownloadsCount--;
		}
		else {
			NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/300x/%@", [b.coverURL rf_urlEncoded]];
			
			[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
					NSImage* img = response.parsedResponse;
					RFDispatchMain(^{
						b.coverImage = img;
						[b setCachedCover:img];
						 
						@try {
							NSIndexSet* selected_rows = [self.tableView selectedRowIndexes];
							[self.tableView reloadData];
							[self.tableView selectRowIndexes:selected_rows byExtendingSelection:NO];
						}
						@catch (NSException* e) {
						}
						
						self.coverDownloadsCount--;
					});
				}
			}];
		}
	}
}

#pragma mark -

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length == 0) {
		self.currentBooks = self.allBooks;
		self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
		[self.tableView reloadData];
		[self setupBooksCount];
	}
	else if (s.length >= 3) {
		[self fetchBooksForSearch:s];
	}
}

- (void) addBookNotification:(NSNotification *)notification
{
	MBBook* b = [[notification userInfo] objectForKey:kAddBookKey];
	RFBookshelf* shelf = [[notification userInfo] objectForKey:kAddBookBookshelfKey];
	if ([shelf.bookshelfID isEqualToNumber:self.bookshelf.bookshelfID]) {
		[self addBook:b toBookshelf:self.bookshelf];
	}
}

- (void) addNoteNotification:(NSNotification *)notification
{
    MBBook* b = [[notification userInfo] objectForKey:kAddNoteBookKey];
	RFBookshelf* shelf = [[notification userInfo] objectForKey:kAddBookBookshelfKey];
	if (![shelf.bookshelfID isEqualToNumber:self.bookshelf.bookshelfID]) {
		// ignore notification if not this bookshelf
		return;
	}

	[self.progressSpinner startAnimation:nil];

	// get the reading notebook
	RFClient* client = [[RFClient alloc] initWithPath:@"/notes/notebooks"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* mb = [item objectForKey:@"_microblog"];
				NSNumber* notebook_id = [item objectForKey:@"id"];
				NSString* notebook_name = [item objectForKey:@"title"];
				NSString* light_color = [[mb objectForKey:@"colors"] objectForKey:@"light"];
				NSString* dark_color = [[mb objectForKey:@"colors"] objectForKey:@"dark"];
				NSString* type = [mb objectForKey:@"type"];

				if ([type isEqualToString:@"reading"] || [notebook_name isEqualToString:@"Reading"]) {
					MBNotebook* nb = [[MBNotebook alloc] init];
					nb.notebookID = notebook_id;
					nb.name = notebook_name;
					nb.lightColor = [NSColor mb_colorFromString:light_color];
					nb.darkColor = [NSColor mb_colorFromString:dark_color];

					RFDispatchMain(^{
						// show note sheet
						self.noteController = [[MBBookNoteController alloc] initWithBook:b readingNotebook:nb];
						[self.window beginSheet:self.noteController.window completionHandler:^(NSModalResponse returnCode) {
							self.noteController = nil;
						}];
					});
				}
			}
		}
		
		RFDispatchMain(^{
			[self.progressSpinner stopAnimation:nil];
		});
	}];
}

- (IBAction) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Remove \"%@\"?", b.title];
		sheet.informativeText = [NSString stringWithFormat:@"This book will be removed from the bookshelf \"%@\".", self.bookshelf.title];
		[sheet addButtonWithTitle:@"Remove"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[self removeBook:b fromBookshelf:self.bookshelf];
			}
		}];
	}
}

- (IBAction) startNewPost:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		
		NSString* link = [b microblogURL];
		NSString* s;
		if (b.authors.count > 0) {
			s = [NSString stringWithFormat:@"%@: [%@](%@) by %@ 📚", self.bookshelf.title, b.title, link, [b.authors firstObject]];
		}
		else {
			s = [NSString stringWithFormat:@"%@: [%@](%@) 📚", self.bookshelf.title, b.title, link];
		}
				
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"microblog://post?text=%@", [s rf_urlEncoded]]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) openInBrowser:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:[b microblogURL]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:[b microblogURL] forType:NSPasteboardTypeString];
	}
}

- (IBAction) copyMarkdown:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		NSString* s = [NSString stringWithFormat:@"[%@](%@)", b.title, [b microblogURL]];
		[pb setString:s forType:NSPasteboardTypeString];
	}
}

- (IBAction) assignToBookshelf:(NSMenuItem *)sender
{
	RFBookshelf* shelf = sender.representedObject;
	if (shelf) {
		NSInteger row = self.tableView.selectedRow;
		if (row >= 0) {
			MBBook* b = [self.currentBooks objectAtIndex:row];
			[self assignBook:b toBookshelf:shelf];
		}
	}
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(assignToBookshelf:)) {
		RFBookshelf* shelf = item.representedObject;
		if ([shelf.bookshelfID isEqualToNumber:self.bookshelf.bookshelfID]) {
			[item setState:NSControlStateValueOn];
		}
		else {
			[item setState:NSControlStateValueOff];
		}
	}
	else if (item.action == @selector(performFindPanelAction:)) {
		return YES;
	}
	else if (item.action == @selector(newDocument:)) {
		NSInteger row = self.tableView.selectedRow;
		if (row >= 0) {
			[item setTitle:@"New Post with Book"];
		}
		else {
			[item setTitle:@"New Post"];
		}
	}

	return ![self isSearch];
}

- (void) performFindPanelAction:(id)sender
{
	[self.searchField becomeFirstResponder];
}

- (void) newDocument:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		[self startNewPost:nil];
	}
	else {
		// try to bubble it up to the top to be handled
		[[NSApplication sharedApplication] tryToPerform:@selector(newDocument:) with:sender];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentBooks.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBBookCell* cell = [tableView makeViewWithIdentifier:@"BookCell" owner:self];

	if (row < self.currentBooks.count) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		[cell setupWithBook:b inBookshelf:self.bookshelf];
	}

	return cell;
}

- (void) tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	MBBook* b = [self.currentBooks objectAtIndex:row];
	
	if ((b.coverImage == nil) && (b.coverURL.length > 0)) {
		[self downloadCoverForBook:b];
	}
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return ![self isSearch];
}

@end
