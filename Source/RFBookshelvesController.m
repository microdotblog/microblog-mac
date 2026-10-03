//
//  RFBookshelvesController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFBookshelvesController.h"

#import "MBBooksWindowController.h"
#import "MBCalendarController.h"
#import "RFBookshelfCell.h"
#import "RFBookshelf.h"
#import "MBGoal.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

static NSInteger const kTimelineBookshelvesSidebarRow = 11;

@interface RFBookshelvesController ()
@property (strong, nonatomic) NSSegmentedControl* tabsControl;
@property (strong, nonatomic) NSLayoutConstraint* goalsPopupWidthConstraint;
@property (strong, nonatomic) MBCalendarController* calendarController;
@property (assign, nonatomic) BOOL showingCalendar;
@end

@interface MBGoalPopUpButtonCell : NSPopUpButtonCell

@end

@implementation MBGoalPopUpButtonCell

- (CGRect) drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
	// get attributed string for text and progress
	NSMenuItem* item = [self selectedItem];
	MBGoal* g = item.representedObject;
	if (!g) {
		return [super drawTitle:title withFrame:frame inView:controlView];
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
	[self setupTabs];
	
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
	// Size the closed popup independently of the menu's two-line goal entries.
	NSPopUpButtonCell* cell = self.goalsPopup.cell;
	cell.usesItemFromMenu = NO;
	cell.menuItem = [[NSMenuItem alloc] initWithTitle:@"Loading Goals…" action:NULL keyEquivalent:@""];
	// placeholder for current year while loading
	self.goalsPopup.enabled = NO;
	self.goalsPopup.hidden = NO;
}

- (void) setupTabs
{
	NSView* header = self.goalsPopup.superview;
	self.tabsControl = [NSSegmentedControl segmentedControlWithLabels:@[ @"Bookshelves", @"Calendar" ] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(selectTab:)];
	self.tabsControl.selectedSegment = 0;
	self.tabsControl.translatesAutoresizingMaskIntoConstraints = NO;
	[header addSubview:self.tabsControl];
	self.goalsPopupWidthConstraint = [self.goalsPopup.widthAnchor constraintEqualToConstant:180];
	[NSLayoutConstraint activateConstraints:@[
		[self.tabsControl.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18],
		[self.tabsControl.centerYAnchor constraintEqualToAnchor:self.goalsPopup.centerYAnchor],
		[self.tabsControl.trailingAnchor constraintLessThanOrEqualToAnchor:self.goalsLabel.leadingAnchor constant:-18],
		self.goalsPopupWidthConstraint
	]];
}

- (void) selectTab:(NSSegmentedControl *)sender
{
	BOOL show_calendar = sender.selectedSegment == 1;
	if (self.showingCalendar == show_calendar) {
		return;
	}
	self.showingCalendar = show_calendar;
	if (self.showingCalendar && !self.calendarController) {
		self.calendarController = [[MBCalendarController alloc] init];
		[self addChildViewController:self.calendarController];
		NSView* calendar_view = self.calendarController.view;
		NSScrollView* shelves_view = self.tableView.enclosingScrollView;
		calendar_view.translatesAutoresizingMaskIntoConstraints = NO;
		[shelves_view.superview addSubview:calendar_view];
		[NSLayoutConstraint activateConstraints:@[
			[calendar_view.leadingAnchor constraintEqualToAnchor:shelves_view.leadingAnchor],
			[calendar_view.trailingAnchor constraintEqualToAnchor:shelves_view.trailingAnchor],
			[calendar_view.topAnchor constraintEqualToAnchor:shelves_view.topAnchor],
			[calendar_view.bottomAnchor constraintEqualToAnchor:shelves_view.bottomAnchor]
		]];
		__weak RFBookshelvesController* weak_self = self;
		self.calendarController.loadingDidChange = ^{
			RFBookshelvesController* controller = weak_self;
			if (controller.showingCalendar && controller.view.window) {
				NSString* name = controller.calendarController.loading ? kTimelineDidStartLoading : kTimelineDidStopLoading;
				[[NSNotificationCenter defaultCenter] postNotificationName:name object:controller userInfo:@{ kTimelineSidebarRowKey: @(kTimelineBookshelvesSidebarRow) }];
			}
		};
	}
	self.tableView.enclosingScrollView.hidden = self.showingCalendar;
	self.calendarController.view.hidden = !self.showingCalendar;
	if (self.showingCalendar) {
		[self.calendarController reloadCalendar];
	}
	else {
		[self stopLoadingSidebarRow];
	}
}

- (void) refresh
{
	if (self.showingCalendar) {
		[self.calendarController reloadCalendar];
	}
	else {
		[self fetchBookshelves];
	}
	[self fetchGoals];
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
				g.year = [[item objectForKey:@"_microblog"] objectForKey:@"goal_year"];
				g.title = [item objectForKey:@"title"];
				g.text = [item objectForKey:@"content_text"];
				g.goalValue = [[item objectForKey:@"_microblog"] objectForKey:@"goal_value"];
				g.goalProgress = [[item objectForKey:@"_microblog"] objectForKey:@"goal_progress"];

				[new_goals addObject:g];
			}
			[new_goals sortUsingComparator:^NSComparisonResult(MBGoal* first, MBGoal* second) {
				return [@(second.year.integerValue) compare:@(first.year.integerValue)];
			}];
			
			RFDispatchMainAsync (^{
				self.goals = new_goals;
				NSNumber* selected_id = self.selectedGoal.goalID;
				self.selectedGoal = new_goals.firstObject;
				for (MBGoal* goal in new_goals) {
					if ([goal.goalID isEqual:selected_id]) {
						self.selectedGoal = goal;
						break;
					}
				}
				[self populatePopup:self.goalsPopup withGoals:self.goals];
				self.goalsPopup.enabled = new_goals.count > 0;
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
	if (!self.showingCalendar || !self.calendarController.loading) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{ kTimelineSidebarRowKey: @(kTimelineBookshelvesSidebarRow) }];
	}
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
	popup.menu.autoenablesItems = NO;

	for (MBGoal* g in goals) {
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:g.title action:NULL keyEquivalent:@""];
		item.attributedTitle = [[self class] attributedMenuTitleForGoal:g];
		item.representedObject = g;
		item.enabled = YES;
		[popup.menu addItem:item];
	}

	if (goals.count > 0) {
		[popup.menu addItem:[NSMenuItem separatorItem]];
		NSMenuItem* edit_item = [popup.menu addItemWithTitle:@"Edit Goal…" action:@selector(editGoal:) keyEquivalent:@""];
		edit_item.target = self;
		MBGoal* newest_goal = goals.firstObject;
		edit_item.toolTip = [NSString stringWithFormat:@"Edit %@", newest_goal.title];
		[self selectCurrentGoalInPopup];
	}
	else {
		[popup addItemWithTitle:@"No Goals"];
		((NSPopUpButtonCell *)popup.cell).menuItem = [[NSMenuItem alloc] initWithTitle:@"No Goals" action:NULL keyEquivalent:@""];
		self.goalsPopupWidthConstraint.constant = 170;
	}
}

- (void) selectCurrentGoalInPopup
{
	if (!self.selectedGoal) {
		return;
	}
	for (NSMenuItem* item in self.goalsPopup.itemArray) {
		if (item.representedObject == self.selectedGoal) {
			[self.goalsPopup selectItem:item];
			NSMenuItem* display_item = [[NSMenuItem alloc] initWithTitle:self.selectedGoal.title action:NULL keyEquivalent:@""];
			display_item.attributedTitle = [[self class] attributedTitleForGoal:self.selectedGoal];
			((NSPopUpButtonCell *)self.goalsPopup.cell).menuItem = display_item;
			// 6-point leading inset, 6-point gap, 10-point arrows, 8-point trailing inset.
			self.goalsPopupWidthConstraint.constant = MAX(170, ceil(display_item.attributedTitle.size.width) + 30);
			[self.goalsPopup invalidateIntrinsicContentSize];
			break;
		}
	}
}

+ (NSAttributedString *) attributedMenuTitleForGoal:(MBGoal *)goal
{
	NSMutableAttributedString* content = [[self attributedTitleForGoal:goal] mutableCopy];
	// Keep this spacing in the menu only; the closed popup uses the compact title.
	NSMutableParagraphStyle* paragraph_style = [[NSMutableParagraphStyle alloc] init];
	paragraph_style.paragraphSpacing = 4;
	[content addAttribute:NSParagraphStyleAttributeName value:paragraph_style range:NSMakeRange(0, content.length)];
	[content appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", goal.text] attributes:@{
		NSFontAttributeName: [NSFont menuFontOfSize:11],
		NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
	}]];
	// AppKit ignores spacing before the first and after the last paragraph.
	// Small blank lines provide outer padding without moving the labels apart.
	NSMutableParagraphStyle* padding_style = [[NSMutableParagraphStyle alloc] init];
	padding_style.minimumLineHeight = 3;
	padding_style.maximumLineHeight = 3;
	NSDictionary* padding_attributes = @{
		NSFontAttributeName: [NSFont menuFontOfSize:3],
		NSParagraphStyleAttributeName: padding_style
	};
	NSMutableAttributedString* title = [[NSMutableAttributedString alloc] initWithString:@" \n" attributes:padding_attributes];
	[title appendAttributedString:content];
	[title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n " attributes:padding_attributes]];
	return title;
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
	NSMenuItem* item = sender.selectedItem;
	if ([item.representedObject isKindOfClass:[MBGoal class]]) {
		self.selectedGoal = item.representedObject;
		[self selectCurrentGoalInPopup];
	}
	else if (item.action == @selector(editGoal:)) {
		[self editGoal:item];
	}
}

- (IBAction) editGoal:(id)sender
{
	// Selecting the command must not replace the compact popup's selected goal.
	[self selectCurrentGoalInPopup];
	MBGoal* goal = self.goals.firstObject;
	if (!goal || !self.view.window || self.view.window.attachedSheet) {
		return;
	}
	self.editTitleField.stringValue = goal.title;
	self.editGoalField.stringValue = [goal.goalValue stringValue];
	
	[self.editSheet makeFirstResponder:self.editGoalField];

	[self.view.window beginSheet:self.editSheet completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[self sendGoal:goal];
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
