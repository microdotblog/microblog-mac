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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookWasAssignedNotification:) name:kBookWasAssignedNotification object:nil];
}

- (void) fetchBookshelves
{
	BOOL first_fetch = (self.bookshelves.count == 0);
	
	self.bookshelves = @[];
	[self.progressSpinner startAnimation:nil];
	if (first_fetch) {
		// only start blank if this is the first time loading bookshelves
		self.tableView.animator.alphaValue = 0.0;
	}

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

- (void) refreshBookshelf:(RFBookshelf *)bookshelf
{
	for (NSInteger i = 0; i < self.bookshelves.count; i++) {
		RFBookshelf* shelf = [self.bookshelves objectAtIndex:i];
		if ([shelf isEqualTo:bookshelf]) {
			RFBookshelfCell* cell = [self.tableView rowViewAtRow:i makeIfNecessary:NO];
			if ([cell isKindOfClass:[RFBookshelfCell class]]) {
				[cell fetchBooks];
			}
			break;
		}
	}
}

- (void) bookWasAddedNotification:(NSNotification *)notification
{
	RFBookshelf* shelf = [notification.userInfo objectForKey:kBookWasAddedBookshelfKey];
	if ([shelf.booksCount integerValue] > 0) {
		[self refreshBookshelf:shelf];
	}
	else {
		[self fetchBookshelves];
	}
}

- (void) bookWasRemovedNotification:(NSNotification *)notification
{
	RFBookshelf* shelf = [notification.userInfo objectForKey:kBookWasAddedBookshelfKey];
	[self refreshBookshelf:shelf];
}

- (void) bookWasAssignedNotification:(NSNotification *)notification
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
	[[NSNotificationCenter defaultCenter] postNotificationName:kOpenBookshelfNotification object:self userInfo:@{ kOpenBookshelfKey: bookshelf }];
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

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	CGFloat result = 44;
	
	if (row < self.bookshelves.count) {
		RFBookshelf* bookshelf = [self.bookshelves objectAtIndex:row];
		if ([bookshelf.booksCount integerValue] > 0) {
			result = 148;
		}
	}
	
	return result;
}

@end
