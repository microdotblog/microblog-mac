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
#import "MBBookCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "NSString+Extras.h"

@implementation MBBooksWindowController

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf
{
	self = [super initWithWindowNibName:@"BooksWindow"];
	if (self) {
		self.bookshelf = bookshelf;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTitle];
	[self setupTable];
	
	[self fetchBooks];
}

- (void) setupTitle
{
	self.window.title = self.bookshelf.title;
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BookCell" bundle:nil] forIdentifier:@"BookCell"];
	[self.tableView setTarget:self];
}

- (void) fetchBooks
{
	self.books = @[];

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
				self.books = new_books;
				[self.tableView reloadData];
			});
		}
	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.books.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBBookCell* cell = [tableView makeViewWithIdentifier:@"BookCell" owner:self];

	if (row < self.books.count) {
		MBBook* b = [self.books objectAtIndex:row];
		[cell setupWithBook:b];
	}

	return cell;
}

- (void) tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	MBBook* b = [self.books objectAtIndex:row];
	
	if (b.coverImage == nil) {
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/300x/%@", [b.coverURL rf_urlEncoded]];

		[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				NSImage* img = response.parsedResponse;
				RFDispatchMain(^{
					b.coverImage = img;
					@try {
						NSIndexSet* selected_rows = [tableView selectedRowIndexes];
						[tableView reloadData];
						[tableView selectRowIndexes:selected_rows byExtendingSelection:NO];
					}
					@catch (NSException* e) {
						NSLog (@"exception");
					}
				});
			}
		}];
	}
}

@end
