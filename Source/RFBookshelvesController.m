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
#import "MBGoal.h"
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
	[self fetchGoals];
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

#pragma mark -

- (void) fetchBookshelves
{
	BOOL first_fetch = (self.bookshelves.count == 0);
	
	self.bookshelves = @[];
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
				shelf.type = [[item objectForKey:@"_microblog"] objectForKey:@"type"];

				[new_bookshelves addObject:shelf];
			}
			
			RFDispatchMainAsync (^{
				self.bookshelves = new_bookshelves;
				[self.tableView reloadData];
				self.tableView.animator.alphaValue = 1.0;
				[self stopLoadingSidebarRow];
			});
		}
	}];
}

- (void) fetchGoals
{
	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/books/goals"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_goals = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBGoal* g = [[MBGoal alloc] init];
				g.goalID = [item objectForKey:@"id"];
				g.title = [item objectForKey:@"title"];
				g.text = [item objectForKey:@"content_text"];
				g.goalValue = [[item objectForKey:@"_microblog"] objectForKey:@"goal_value"];
				g.goalProgress = [[item objectForKey:@"_microblog"] objectForKey:@"goal_progress"];

				[new_goals addObject:g];
			}
			
			RFDispatchMainAsync (^{
				self.goals = new_goals;
				[self populatePopup:self.goalsPopup withGoals:self.goals];
			});
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

- (void) refreshBookshelf:(RFBookshelf *)bookshelf
{
	for (NSInteger i = 0; i < self.bookshelves.count; i++) {
		RFBookshelf* shelf = [self.bookshelves objectAtIndex:i];
		if ([shelf isEqualToBookshelf:bookshelf]) {
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

- (void) populatePopup:(NSPopUpButton *)popup withGoals:(NSArray *)goals
{
	[popup removeAllItems];

	for (MBGoal* g in goals) {
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		item.attributedTitle = [self attributedTitleForGoal:g];
		item.enabled = YES;
		[popup.menu addItem:item];
	}

	[popup selectItemAtIndex:0];
}

- (NSAttributedString *) attributedTitleForGoal:(MBGoal *)goal
{
	NSImage* bar_img = [self imageForProgress:goal.goalProgress.doubleValue max:goal.goalValue.doubleValue size:NSMakeSize(60, 10)];

	// create attachment
	NSTextAttachment *att = [[NSTextAttachment alloc] init];
	att.image = bar_img;

	att.bounds = NSMakeRect(0, 0, bar_img.size.width, bar_img.size.height);
	NSAttributedString* img_attr = [NSAttributedString attributedStringWithAttachment:att];
	
	// append text
	NSFont* f = [NSFont menuFontOfSize:13];
	NSString* s = [NSString stringWithFormat:@"%@ ", goal.title];
	NSMutableAttributedString* title_attr = [[NSMutableAttributedString alloc] initWithString:s attributes:@{ NSFontAttributeName: f }];
	[title_attr appendAttributedString:img_attr];
	
	return title_attr;
}

- (NSImage*) imageForProgress:(CGFloat)progress max:(CGFloat)maxSize size:(NSSize)size
{
	NSImage* img = [[NSImage alloc] initWithSize:size];
	[img lockFocus];
	
	CGFloat inset = 5;
	CGFloat corner_radius = 3;
	
	// background
	[[NSColor lightGrayColor] setFill];
	NSBezierPath* bg = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(inset, 0, size.width - inset, size.height) xRadius:corner_radius yRadius:corner_radius];
	[bg fill];
	
	// fill
	CGFloat fraction = (maxSize > 0) ? (progress / maxSize) : 0;
	NSRect fill = NSMakeRect(inset, 0, size.width - inset, size.height);
	fill.size.width *= MIN(MAX(fraction, 0), 1);
	[[NSColor darkGrayColor] setFill];
	NSBezierPath* fg = [NSBezierPath bezierPathWithRoundedRect:fill xRadius:corner_radius yRadius:corner_radius];
	[fg fill];
	
	[img unlockFocus];
	return img;
}

- (IBAction) goalsPopupChanged:(NSPopUpButton *)sender
{
	MBGoal* g = [self.goals objectAtIndex:sender.indexOfSelectedItem];
	self.goalsPopup.attributedTitle = [self attributedTitleForGoal:g];
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
