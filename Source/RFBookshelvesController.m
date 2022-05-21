//
//  RFBookshelvesController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFBookshelvesController.h"

#import "MBBooksWindowController.h"
#import "RFBookshelfCell.h"
#import "RFBookshelf.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

@implementation RFBookshelvesController

- (id) init
{
	self = [super initWithNibName:@"Bookshelves" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	[self setupNotifications];
	
	[self fetchBookshelves];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BookshelfCell" bundle:nil] forIdentifier:@"BookshelfCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookWasAddedNotification:) name:kBookWasAddedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookWasRemovedNotification:) name:kBookWasRemovedNotification object:nil];
}

- (void) fetchBookshelves
{
	self.bookshelves = @[];
	[self.progressSpinner startAnimation:nil];
	self.tableView.animator.alphaValue = 0.0;

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

				[new_bookshelves addObject:shelf];
			}
			
			RFDispatchMainAsync (^{
				self.bookshelves = new_bookshelves;
				[self.tableView reloadData];
				[self.progressSpinner stopAnimation:nil];
				self.tableView.animator.alphaValue = 1.0;
			});
		}
	}];
}

- (void) bookWasAddedNotification:(NSNotification *)notification
{
	[self fetchBookshelves];
}

- (void) bookWasRemovedNotification:(NSNotification *)notification
{
	[self fetchBookshelves];
}

#pragma mark -

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		RFBookshelf* bookshelf = [self.bookshelves objectAtIndex:row];
		[self openBookshelf:bookshelf];
	}
}

- (void) openBookshelf:(RFBookshelf *)bookshelf
{
	MBBooksWindowController* books_controller = [[MBBooksWindowController alloc] initWithBookshelf:bookshelf];
	[books_controller showWindow:nil];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.bookshelves.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFBookshelfCell* cell = [tableView makeViewWithIdentifier:@"BookshelfCell" owner:self];

	if (row < self.bookshelves.count) {
		RFBookshelf* bookshelf = [self.bookshelves objectAtIndex:row];
		[cell setupWithBookshelf:bookshelf];
	}

	return cell;
}

@end
