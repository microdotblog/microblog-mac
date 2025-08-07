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

@interface MBGoalPopUpButtonCell : NSPopUpButtonCell

@property (nonatomic, strong) NSAttributedString *overrideTitle;

@end

@implementation MBGoalPopUpButtonCell

- (CGRect) drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
	// get attributed string for text and progress
	NSMenuItem* item = [self selectedItem];
	MBGoal* g = item.representedObject;
	if (!g) {
		return frame;
	}
	NSAttributedString* s = [RFBookshelvesController attributedTitleForGoal:g];
	
	// draw custom rounded rect background
	CGFloat corner_radius = 6;
	NSRect bg_r = controlView.bounds;
	NSBezierPath* bg_path = [NSBezierPath bezierPathWithRoundedRect:bg_r xRadius:corner_radius yRadius:corner_radius];
	[[NSColor colorNamed:@"color_popup_background"] setFill];
	[bg_path fill];
	
	// draw disclosure arrows
	NSImage* disclosure_img = [NSImage imageWithSystemSymbolName:@"chevron.up.chevron.down" accessibilityDescription:@"popup disclosure arrows"];
	CGFloat side = 10;
	NSRect icon_r = NSMakeRect(
		NSMaxX(controlView.bounds) - side - 8,
		NSMidY(controlView.bounds) - (side / 2),
		side, side
	);
	[disclosure_img drawInRect:icon_r fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];

	// use TextKit to make sure attachments draw
	NSMutableAttributedString* label_s = [[NSMutableAttributedString alloc] initWithAttributedString:s];
	[label_s addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:NSMakeRange(0, label_s.length)];
	NSTextStorage* storage = [[NSTextStorage alloc] initWithAttributedString:label_s];
	NSTextContainer* container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(CGFLOAT_MAX, frame.size.height)];
	container.lineFragmentPadding = 0;
	NSLayoutManager* manager = [[NSLayoutManager alloc] init];
	[manager addTextContainer:container];
	[storage addLayoutManager:manager];
	[manager glyphRangeForTextContainer:container];
	[manager drawGlyphsForGlyphRange:[manager glyphRangeForTextContainer:container] atPoint:frame.origin];
	
	return frame;
}

@end

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
	[self setupPlaceholder];
	
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

- (void) setupPlaceholder
{
	// placeholder for current year while loading
	self.goalsPopup.title = @"Reading 2025";
	self.goalsPopup.enabled = NO;
	self.goalsPopup.hidden = NO;
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
			__block BOOL is_first = YES;
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
				
				RFDispatchMainAsync (^{
					if (is_first) {
						self.selectedGoal = g;
						self.goalSummaryField.stringValue = g.text;
						self.goalSummaryField.hidden = NO;
						is_first = NO;
					}
				});
			}
			
			RFDispatchMainAsync (^{
				self.goals = new_goals;
				[self populatePopup:self.goalsPopup withGoals:self.goals];
				self.goalsPopup.enabled = YES;
				self.editButton.enabled = YES;
			});
		}
	}];
}

- (void) sendGoal:(MBGoal *)goal
{
	goal.goalValue = [NSNumber numberWithInt:self.editGoalField.intValue];
	
	NSMutableDictionary* info = [NSMutableDictionary dictionary];
	[info setObject:goal.goalValue forKey:@"value"];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/books/goals/%@", goal.goalID];
	[client postWithParams:info completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self fetchGoals];
		});
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
		item.attributedTitle = [[self class] attributedTitleForGoal:g];
		item.representedObject = g;
		item.enabled = YES;
		[popup.menu addItem:item];
	}

	[popup selectItemAtIndex:0];
}

+ (NSAttributedString *) attributedTitleForGoal:(MBGoal *)goal
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

+ (NSImage*) imageForProgress:(CGFloat)progress max:(CGFloat)maxSize size:(NSSize)size
{
	NSImage* img = [[NSImage alloc] initWithSize:size];
	[img lockFocus];
	
	// inset a little on the left for spacing
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
	self.selectedGoal = [self.goals objectAtIndex:sender.indexOfSelectedItem];
	self.goalSummaryField.stringValue = self.selectedGoal.text;
}

- (IBAction) editGoal:(id)sender
{
	self.editTitleField.stringValue = self.selectedGoal.title;
	self.editGoalField.stringValue = [self.selectedGoal.goalValue stringValue];
	
	[self.editSheet makeFirstResponder:self.editGoalField];

	[self.view.window beginSheet:self.editSheet completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[self sendGoal:self.selectedGoal];
		}
	}];
}

- (IBAction) updateGoal:(id)sender
{
	[self.view.window endSheet:self.editSheet returnCode:NSModalResponseOK];
}

- (IBAction) cancelGoal:(id)sender
{
	[self.view.window endSheet:self.editSheet returnCode:NSModalResponseCancel];
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
