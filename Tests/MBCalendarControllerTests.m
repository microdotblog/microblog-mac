#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "MBCalendarController.h"
#import "RFBookshelvesController.h"
#import "RFBookshelfCell.h"
#import "RFClient.h"
#import "RFSettings.h"

// Link production calendar/bookshelf controllers with these network doubles.
// Pass the built app bundle and optional calendar JSON fixture as arguments.
static NSMutableArray* requests;
static NSString* username = @"test-account";
static NSBundle* app_bundle;

@interface NSColor (CalendarTestAssets)
+ (NSColor *) calendarTestColorNamed:(NSString *)name;
@end
@implementation NSColor (CalendarTestAssets)
+ (NSColor *) calendarTestColorNamed:(NSString *)name
{
	return [self calendarTestColorNamed:name] ?: [self colorNamed:name bundle:app_bundle];
}
@end

@implementation RFSettings
+ (NSString *) stringForKey:(NSString *)key { return username; }
@end
@implementation UUHttpResponse
@end
@implementation RFBookshelfCell
@end
@implementation RFClient
- (instancetype) initWithPath:(NSString *)path
{
	self = [super init];
	self.path = path;
	return self;
}
- (instancetype) initWithFormat:(NSString *)format, ...
{
	va_list arguments;
	va_start(arguments, format);
	NSString* path = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	return [self initWithPath:path];
}
- (UUHttpRequest *) getWithCompletion:(void (^)(UUHttpResponse* response))handler
{
	[requests addObject:@{ @"path": self.path, @"completion": [handler copy] }];
	return nil;
}
- (UUHttpRequest *) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	return [self getWithCompletion:handler];
}
- (UUHttpRequest *) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse* response))handler
{
	[requests addObject:@{ @"path": self.path, @"params": params, @"completion": [handler copy] }];
	return nil;
}
@end

@interface MBCalendarController (Testing)
+ (NSArray *) monthsFromResponse:(id)response;
- (NSImage *) imageForURL:(NSString *)url;
- (NSImage *) calendarTestImageForURL:(NSString *)url;
- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row;
@end
@implementation MBCalendarController (Testing)
- (NSImage *) calendarTestImageForURL:(NSString *)url
{
	// Integration rendering uses only the synthetic images populated below.
	return [[self valueForKey:@"images"] objectForKey:url];
}
@end
@interface RFBookshelvesController (Testing)
- (void) selectTab:(NSSegmentedControl *)sender;
- (void) setupTable;
- (void) fetchGoals;
- (IBAction) goalsPopupChanged:(NSPopUpButton *)sender;
- (IBAction) updateGoal:(id)sender;
+ (NSAttributedString *) attributedMenuTitleForGoal:(MBGoal *)goal;
@end

@interface CalendarBookshelvesTestController : RFBookshelvesController
@end
@implementation CalendarBookshelvesTestController
- (id) init
{
	return [super initWithNibName:@"Bookshelves" bundle:app_bundle];
}
- (void) setupTable
{
	// No shelf cells are needed for this test's empty bookshelf response.
}
@end

static void Pump(void)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void Reply(NSUInteger index, NSInteger status, id payload)
{
	UUHttpResponse* response = [UUHttpResponse new];
	response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://micro.blog/books/calendar"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
	response.parsedResponse = payload;
	void (^handler)(UUHttpResponse*) = requests[index][@"completion"];
	handler(response);
	Pump();
}

static void Render(NSView* view, NSString* path)
{
	[view layoutSubtreeIfNeeded];
	NSBitmapImageRep* rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

int main(int argc, const char* argv[])
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		requests = [NSMutableArray array];
		NSDictionary* book = @{ @"title": @"A Finished Book", @"author": @"An Author", @"day": @2, @"finished_label": @"Oct 2", @"page_count": @384 };
		NSDictionary* fixture = @{ @"months": @[ @{ @"year": @2026, @"month": @10, @"books": @[ book ], @"book_count": @1, @"page_count": @384, @"background_color": @"#d2a530" } ] };
		if (argc > 2) {
			NSData* data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
			fixture = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		}
		NSCAssert(fixture != nil, @"Fixture must parse");
		NSArray* months = [MBCalendarController monthsFromResponse:fixture];
		NSCAssert(months.count > 0, @"Fixture must contain calendar months");
		NSCAssert([MBCalendarController monthsFromResponse:@{}] == nil, @"Missing months is an error, not an empty calendar");
		NSCAssert([MBCalendarController monthsFromResponse:@{ @"months": @[] }].count == 0, @"Empty calendars must be accepted");
		NSArray* malformed = @[ NSNull.null, @{ @"year": @2026, @"month": @13, @"books": @[] }, @{ @"year": @2026, @"month": @10, @"books": @[ NSNull.null, book ] } ];
		NSArray* cleaned = [MBCalendarController monthsFromResponse:@{ @"months": malformed }];
		NSCAssert(cleaned.count == 1 && [cleaned[0][@"books"] count] == 1, @"Invalid months and non-book entries must be ignored safely");
		MBCalendarController* controller = [MBCalendarController new];
		__block NSInteger loading_changes = 0;
		controller.loadingDidChange = ^{ loading_changes++; };
		[controller reloadCalendar];
		NSCAssert(controller.loading && [requests[0][@"path"] isEqual:@"/books/calendar"], @"Calendar must use authenticated client path and expose loading");
		Reply(0, 200, fixture);
		NSTableView* table = [controller valueForKey:@"tableView"];
		NSCAssert([controller imageForURL:@""] == nil && [controller imageForURL:@"file:///private/tmp/cover.jpg"] == nil, @"Missing and non-HTTP image URLs must not start downloads");
		NSCAssert(!controller.loading && loading_changes == 2 && table.numberOfRows == months.count, @"Successful response must render months and stop progress");
		NSCAssert(![controller tableView:table shouldSelectRow:0] && table.menu == nil && table.doubleAction == NULL, @"Calendar rows must be read-only");
		[controller reloadCalendar];
		[controller reloadCalendar];
		Reply(1, 200, @{ @"months": @[] });
		NSCAssert(controller.loading && table.numberOfRows == months.count, @"Stale reload responses must not change current data or spinner");
		Reply(2, 200, @{ @"months": @[] });
		NSTextField* message = [controller valueForKey:@"messageLabel"];
		NSCAssert(!controller.loading && !message.hidden && table.numberOfRows == 0, @"Empty response must show empty state");
		[controller reloadCalendar];
		Reply(3, 502, nil);
		NSCAssert(!controller.loading && ![[controller valueForKey:@"retryButton"] isHidden], @"Server failures must stop progress and offer Retry");
		[controller reloadCalendar];
		username = @"other-account";
		Reply(4, 200, fixture);
		NSCAssert(!controller.loading && table.numberOfRows == 0, @"Responses from a previous account must not populate the calendar");
		username = @"test-account";
		if (argc > 1) {
			app_bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
			method_exchangeImplementations(class_getClassMethod(NSColor.class, @selector(colorNamed:)), class_getClassMethod(NSColor.class, @selector(calendarTestColorNamed:)));
			method_exchangeImplementations(class_getInstanceMethod(MBCalendarController.class, @selector(imageForURL:)), class_getInstanceMethod(MBCalendarController.class, @selector(calendarTestImageForURL:)));
			CalendarBookshelvesTestController* shelves = [CalendarBookshelvesTestController new];
			NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 720) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			NSUInteger initial_request = requests.count;
			window.contentViewController = shelves;
			Pump();
			NSDictionary* goals_fixture = @{ @"items": @[
				@{ @"id": @25, @"title": @"Reading 2025", @"content_text": @"5 of 30 books", @"_microblog": @{ @"goal_year": @2025, @"goal_value": @30, @"goal_progress": @5 } },
				@{ @"id": @26, @"title": @"Reading 2026", @"content_text": @"7 of 40 books", @"_microblog": @{ @"goal_year": @2026, @"goal_value": @40, @"goal_progress": @7 } }
			] };
			Reply(initial_request + 1, 200, goals_fixture);
			NSMenu* menu = shelves.goalsPopup.menu;
			NSCAssert(menu.numberOfItems == 4 && [menu itemAtIndex:2].separatorItem && [[menu itemAtIndex:3].title isEqual:@"Edit Goal…"], @"Goals menu must end with separator and Edit Goal…");
			NSCAssert(shelves.selectedGoal.year.integerValue == 2026 && [[menu itemAtIndex:0].attributedTitle attribute:NSAttachmentAttributeName atIndex:15 effectiveRange:NULL] != nil, @"Newest goal must be first, with a progress attachment");
			NSCAssert([[menu itemAtIndex:0].attributedTitle.string containsString:@"\n7 of 40 books"], @"Goal progress summary must appear underneath the goal name");
			NSMenu* single_line = [NSMenu new];
			NSMenuItem* single_item = [single_line addItemWithTitle:@"Reading 2026" action:NULL keyEquivalent:@""];
			single_item.attributedTitle = [RFBookshelvesController attributedTitleForGoal:shelves.selectedGoal];
			NSMenu* two_lines = [NSMenu new];
			NSMenuItem* two_line_item = [two_lines addItemWithTitle:@"Reading 2026" action:NULL keyEquivalent:@""];
			two_line_item.attributedTitle = [RFBookshelvesController attributedMenuTitleForGoal:shelves.selectedGoal];
			NSCAssert(two_lines.size.height > single_line.size.height, @"Menu must reserve height for both lines");
			NSCAssert(shelves.goalsPopup.intrinsicContentSize.width <= 200 && menu.size.width <= 210, @"Multiline goal counts must not widen the compact popup or menu: intrinsic %@ cell %@ menu %@", NSStringFromSize(shelves.goalsPopup.intrinsicContentSize), NSStringFromSize([shelves.goalsPopup.cell cellSize]), NSStringFromSize(menu.size));
			NSColor* count_color = [[menu itemAtIndex:0].attributedTitle attribute:NSForegroundColorAttributeName atIndex:[menu itemAtIndex:0].attributedTitle.length - 3 effectiveRange:NULL];
			NSCAssert([count_color isEqual:[NSColor secondaryLabelColor]], @"Menu book counts must use secondary gray text");
			NSParagraphStyle* title_style = [two_line_item.attributedTitle attribute:NSParagraphStyleAttributeName atIndex:2 effectiveRange:NULL];
			NSCAssert(title_style.paragraphSpacing == 4, @"Title-to-count spacing must stay four points");
			NSAttributedString* unpadded_title = [two_line_item.attributedTitle attributedSubstringFromRange:NSMakeRange(2, two_line_item.attributedTitle.length - 4)];
			NSMenu* unpadded_menu = [NSMenu new];
			[unpadded_menu addItemWithTitle:@"Reading 2026" action:NULL keyEquivalent:@""].attributedTitle = unpadded_title;
			NSCAssert(two_lines.size.height >= unpadded_menu.size.height + 6, @"Goal entries must add outer padding without changing the four-point title-to-count gap: padded %@ unpadded %@", NSStringFromSize(two_lines.size), NSStringFromSize(unpadded_menu.size));
			[shelves.goalsPopup selectItemAtIndex:1];
			[shelves goalsPopupChanged:shelves.goalsPopup];
			NSCAssert(shelves.selectedGoal.year.integerValue == 2025, @"Older goals must remain selectable");
			[window orderFront:nil];
			[menu performActionForItemAtIndex:3];
			Pump();
			NSCAssert(window.attachedSheet == shelves.editSheet && [shelves.editTitleField.stringValue isEqual:@"Reading 2026"] && shelves.editGoalField.integerValue == 40, @"Edit Goal must edit newest goal, not selected older goal");
			NSCAssert(shelves.goalsPopup.selectedItem.representedObject == shelves.selectedGoal, @"Edit command must not become the popup's selected value");
			shelves.editGoalField.integerValue = 50;
			[shelves updateGoal:nil];
			Pump();
			NSCAssert([requests.lastObject[@"path"] isEqual:@"/books/goals/26"] && [requests.lastObject[@"params"][@"value"] integerValue] == 50, @"Saving must post to newest goal ID");
			Reply(requests.count - 1, 200, @{});
			Reply(requests.count - 1, 200, goals_fixture);
			NSCAssert(shelves.selectedGoal.year.integerValue == 2025 && shelves.goalsPopup.selectedItem.representedObject == shelves.selectedGoal, @"Goal refresh must preserve the user's selected older goal");
			[window orderOut:nil];
			NSSegmentedControl* tabs = [shelves valueForKey:@"tabsControl"];
			NSCAssert(tabs.segmentCount == 2 && tabs.selectedSegment == 0 && [[tabs labelForSegment:0] isEqual:@"Bookshelves"], @"Header must start with native Bookshelves and Calendar segments");
			tabs.selectedSegment = 1;
			[shelves selectTab:tabs];
			MBCalendarController* calendar = [shelves valueForKey:@"calendarController"];
			NSCAssert(calendar.view.superview != nil && shelves.tableView.enclosingScrollView.hidden && calendar.loading, @"Calendar must replace only the shelf content while loading");
			Reply(requests.count - 1, 200, fixture);
			NSMutableSet* requested_images = [calendar valueForKey:@"requestedImages"];
			NSCache* images = [calendar valueForKey:@"images"];
			// Use synthetic local image stand-ins; no account or remote image requests.
			NSImage* cover = [NSImage imageWithSize:NSMakeSize(100, 160) flipped:NO drawingHandler:^BOOL(NSRect rect) {
				[[NSColor systemRedColor] setFill];
				NSRectFill(rect);
				return YES;
			}];
			for (NSDictionary* month in months) {
				if ([month[@"background_url"] isKindOfClass:[NSString class]]) {
					[requested_images addObject:month[@"background_url"]];
				}
				for (NSDictionary* item in month[@"books"]) {
					if ([item[@"cover_url"] isKindOfClass:[NSString class]]) {
						[images setObject:cover forKey:item[@"cover_url"]];
					}
				}
			}
			for (NSNumber* width in @[ @700, @440 ]) {
				[window setContentSize:NSMakeSize(width.doubleValue, 720)];
				Pump();
				[window.contentView layoutSubtreeIfNeeded];
				NSRect segments = [tabs alignmentRectForFrame:tabs.frame];
				NSRect label = [shelves.goalsLabel alignmentRectForFrame:shelves.goalsLabel.frame];
				NSRect popup = [shelves.goalsPopup alignmentRectForFrame:shelves.goalsPopup.frame];
				CGFloat expected_width = ceil([RFBookshelvesController attributedTitleForGoal:shelves.selectedGoal].size.width) + 30;
				NSCAssert(fabs(NSWidth(popup) - expected_width) < 0.1, @"Goals popup must leave only six points between progress bar and arrows");
				NSCAssert(fabs(NSMinX(segments) - 18) < 0.1 && NSMaxX(segments) <= NSMinX(label) - 17 && NSMaxX(label) < NSMinX(popup), @"Segments must align left and goals right without overlap");
				Render(window.contentView, [NSString stringWithFormat:@"/private/tmp/microblog-calendar-%@.png", width]);
			}
			tabs.selectedSegment = 0;
			[shelves selectTab:tabs];
			NSCAssert(!shelves.tableView.enclosingScrollView.hidden && calendar.view.hidden, @"Toggle must restore the existing shelf view");
			tabs.selectedSegment = 1;
			[shelves selectTab:tabs];
			NSCAssert([shelves valueForKey:@"calendarController"] == calendar, @"Repeated toggles must reuse the existing calendar controller");
			Reply(requests.count - 1, 200, fixture);
			for (NSDictionary* month in months) {
				if ([month[@"background_url"] isKindOfClass:[NSString class]]) {
					[requested_images addObject:month[@"background_url"]];
				}
			}
			window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
			[window setContentSize:NSMakeSize(700, 720)];
			Pump();
			Render(window.contentView, @"/private/tmp/microblog-calendar-dark.png");
			[shelves fetchGoals];
			Reply(requests.count - 1, 200, @{ @"items": @[] });
			NSCAssert(!shelves.goalsPopup.enabled && [((NSPopUpButtonCell *)shelves.goalsPopup.cell).menuItem.title isEqual:@"No Goals"] && shelves.selectedGoal == nil && shelves.goalsPopup.numberOfItems == 1, @"Empty goals must have a disabled placeholder without an edit command");
			[window orderOut:nil];
		}
		NSLog(@"Passed calendar parsing, request lifecycle, read-only behavior, and optional bookshelf layout/toggle checks.");
	}
	return 0;
}
