#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "MBCalendarController.h"
#import "MBCalendarMonthView.h"
#import "RFBookshelvesController.h"
#import "RFBookshelfCell.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "MBBook.h"
#import "RFConstants.h"
#import <stdatomic.h>

// Link production calendar/bookshelf controllers with these network doubles.
// Pass the built app bundle and optional calendar JSON fixture as arguments.
static NSMutableArray* requests;
static NSMutableArray* page_requests;
static NSMutableArray* page_posts;
static NSString* username = @"test-account";
static NSString* destination_uid = @"test-destination";
static NSString* blog_hostname = @"calendar.test";
static BOOL has_hosted_blog = YES;
static NSString* last_page_error;
static NSBundle* app_bundle;
static NSMutableArray* opened_urls;
static NSString* image_cache_root;
static NSData* image_response_data;
static atomic_int image_request_count;
NSString* const kUUHttpSessionErrorDomain = @"TestHttpError";
NSString* const kUUHttpSessionHttpErrorCodeKey = @"status";

@interface MBBook (CalendarTestCache)
+ (NSString *) calendarTestCachePath:(NSString *)filename inFolder:(NSString *)folderName;
@end
@implementation MBBook (CalendarTestCache)
+ (NSString *) calendarTestCachePath:(NSString *)filename inFolder:(NSString *)folderName
{
	NSString* folder = [image_cache_root stringByAppendingPathComponent:folderName];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
	return [folder stringByAppendingPathComponent:filename];
}
@end

@interface CalendarImageTestProtocol : NSURLProtocol
@end
@implementation CalendarImageTestProtocol
+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	return YES;
}
+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}
- (void) startLoading
{
	atomic_fetch_add(&image_request_count, 1);
	NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[self.client URLProtocol:self didLoadData:image_response_data];
	[self.client URLProtocolDidFinishLoading:self];
}
- (void) stopLoading
{
}
@end

@interface NSWorkspace (CalendarTestBrowser)
- (BOOL) calendarTestOpenURL:(NSURL *)url;
@end
@implementation NSWorkspace (CalendarTestBrowser)
- (BOOL) calendarTestOpenURL:(NSURL *)url
{
	[opened_urls addObject:url];
	return YES;
}
@end

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
+ (NSString *) stringForKey:(NSString *)key
{
	if ([key isEqual:kCurrentDestinationUID]) {
		return destination_uid;
	}
	if ([key isEqual:kCurrentDestinationName] || [key isEqual:kAccountDefaultSite]) {
		return blog_hostname;
	}
	return username;
}
+ (BOOL) boolForKey:(NSString *)key
{
	return has_hosted_blog;
}
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
	if ([self.path isEqual:@"/micropub"] && [args[@"mp-channel"] isEqual:@"pages"]) {
		[page_requests addObject:@{ @"path": self.path, @"args": args, @"completion": [handler copy] }];
		return nil;
	}
	return [self getWithCompletion:handler];
}
- (UUHttpRequest *) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse* response))handler
{
	NSMutableArray* target = [params[@"mp-channel"] isEqual:@"pages"] ? page_posts : requests;
	[target addObject:@{ @"path": self.path, @"params": params, @"completion": [handler copy] }];
	return nil;
}
@end

@interface MBCalendarController (Testing)
+ (NSArray *) monthsFromResponse:(id)response;
- (NSImage *) imageForURL:(NSString *)url;
- (NSImage *) calendarTestImageForURL:(NSString *)url;
- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row;
+ (NSNumber *) responseContainsCalendarPage:(id)response;
- (void) checkCalendarPage;
- (void) addCalendarPage:(id)sender;
- (void) showPageCreationError:(NSString *)message;
@end
@interface MBCalendarMonthView (Testing)
- (void) drawImage:(NSImage *)image inRect:(NSRect)rect fill:(BOOL)shouldFill dimmed:(BOOL)dimmed;
@end
@implementation MBCalendarController (Testing)
- (NSImage *) calendarTestImageForURL:(NSString *)url
{
	// Integration rendering uses only the synthetic images populated below.
	return [[self valueForKey:@"images"] objectForKey:url];
}
@end

@interface CalendarPageTestController : MBCalendarController
@end
@implementation CalendarPageTestController
- (void) showPageCreationError:(NSString *)message
{
	last_page_error = message;
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

static void ReplyRequest(NSDictionary* request, NSInteger status, id payload)
{
	UUHttpResponse* response = [UUHttpResponse new];
	response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://micro.blog/books/calendar"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
	response.parsedResponse = payload;
	void (^handler)(UUHttpResponse*) = request[@"completion"];
	handler(response);
	Pump();
}

static void Reply(NSUInteger index, NSInteger status, id payload)
{
	ReplyRequest(requests[index], status, payload);
}

static NSBitmapImageRep* Render(NSView* view, NSString* path)
{
	[view layoutSubtreeIfNeeded];
	NSBitmapImageRep* rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
	return rep;
}

static void ClickMonthWithModifiers(NSTableView* table, NSInteger row, NSPoint point, NSInteger clickCount, NSEventModifierFlags modifiers)
{
	NSView* cell = [table viewAtColumn:0 row:row makeIfNecessary:YES];
	NSPoint location = [cell convertPoint:point toView:nil];
	NSEvent* event = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:location modifierFlags:modifiers timestamp:0 windowNumber:table.window.windowNumber context:nil eventNumber:1 clickCount:clickCount pressure:1];
	NSView* hit_view = [table hitTest:[table.superview convertPoint:location fromView:nil]];
	[hit_view mouseDown:event];
}

static void ClickMonth(NSTableView* table, NSInteger row, NSPoint point, NSInteger clickCount)
{
	ClickMonthWithModifiers(table, row, point, clickCount, 0);
}

static void PressKey(NSTableView* table, unichar key, NSEventModifierFlags modifiers)
{
	NSString* characters = [NSString stringWithCharacters:&key length:1];
	NSEvent* event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:modifiers timestamp:0 windowNumber:table.window.windowNumber context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:0];
	[table keyDown:event];
}

static void AssertSelection(MBCalendarController* controller, NSUInteger row, NSUInteger bookIndex)
{
	NSIndexPath* expected = [[NSIndexPath indexPathWithIndex:row] indexPathByAddingIndex:bookIndex];
	NSCAssert([[controller valueForKey:@"selectedBookIndexPath"] isEqual:expected], @"Keyboard selection must match month %lu, book %lu", row, bookIndex);
	NSTableView* table = [controller valueForKey:@"tableView"];
	MBCalendarMonthView* cell = [table viewAtColumn:0 row:row makeIfNecessary:YES];
	NSCAssert(cell.selectedBookIndex == bookIndex, @"Keyboard selection must update the visible card");
}

static MBCalendarController* ImageCacheController(NSArray* months)
{
	MBCalendarController* controller = [MBCalendarController new];
	[controller view];
	[controller setValue:months forKey:@"months"];
	NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	configuration.protocolClasses = @[ CalendarImageTestProtocol.class ];
	configuration.URLCache = nil;
	[controller setValue:[NSURLSession sessionWithConfiguration:configuration] forKey:@"imageSession"];
	return controller;
}

static NSImage* WaitForImage(MBCalendarController* controller, NSString* url)
{
	[controller imageForURL:url];
	NSCache* images = [controller valueForKey:@"images"];
	for (NSInteger i = 0; i < 100 && ![images objectForKey:url]; i++) {
		Pump();
	}
	NSImage* image = [images objectForKey:url];
	NSCAssert(image.isValid, @"Image must finish loading from disk or network");
	return image;
}

int main(int argc, const char* argv[])
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		requests = [NSMutableArray array];
		page_requests = [NSMutableArray array];
		page_posts = [NSMutableArray array];
		opened_urls = [NSMutableArray array];
		image_cache_root = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"CalendarCacheTests-" stringByAppendingString:NSUUID.UUID.UUIDString]];
		method_exchangeImplementations(class_getClassMethod(MBBook.class, @selector(pathForCachedImage:inFolder:)), class_getClassMethod(MBBook.class, @selector(calendarTestCachePath:inFolder:)));
		NSImage* cache_fixture = [NSImage imageWithSize:NSMakeSize(20, 30) flipped:NO drawingHandler:^BOOL(NSRect rect) {
			[[NSColor redColor] setFill];
			NSRectFill(rect);
			return YES;
		}];
		image_response_data = cache_fixture.TIFFRepresentation;
		MBBook* cached_book = [MBBook new];
		cached_book.isbn = @"9781250462657";
		[cached_book setCachedCover:cache_fixture];
		NSCAssert([cached_book cachedCover].isValid, @"Existing book cover cache must persist images by ISBN");
		cached_book.isbn = @"../invalid";
		NSCAssert([cached_book pathForCachedCover] == nil, @"Invalid ISBN paths must not escape the cover folder");
		cached_book.isbn = @"9781250462657";
		NSString* cover_url = @"https://calendar.test/cover.jpg";
		NSString* background_url = @"https://calendar.test/background.jpg";
		NSArray* cache_months = @[ @{ @"background_url": background_url, @"books": @[ @{ @"cover_url": cover_url, @"isbn": cached_book.isbn } ] } ];
		MBCalendarController* cache_controller = ImageCacheController(cache_months);
		WaitForImage(cache_controller, cover_url);
		NSCAssert(atomic_load(&image_request_count) == 0, @"Calendar must reuse existing bookshelf covers without a download");
		WaitForImage(cache_controller, background_url);
		NSCAssert(atomic_load(&image_request_count) == 1, @"Missing background must download once");
		NSString* background_folder = [image_cache_root stringByAppendingPathComponent:@"Book Backgrounds"];
		NSArray* background_files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:background_folder error:nil];
		NSCAssert(background_files.count == 1, @"Backgrounds must be persisted in Book Backgrounds");
		cache_controller = ImageCacheController(cache_months);
		WaitForImage(cache_controller, cover_url);
		WaitForImage(cache_controller, background_url);
		NSCAssert(atomic_load(&image_request_count) == 1, @"A new controller must load covers and backgrounds from disk, not network");
		[[NSFileManager defaultManager] removeItemAtPath:[cached_book pathForCachedCover] error:nil];
		cache_controller = ImageCacheController(cache_months);
		WaitForImage(cache_controller, cover_url);
		NSCAssert(atomic_load(&image_request_count) == 2 && [cached_book cachedCover].isValid, @"Calendar downloads must populate the shared ISBN cover cache");
		NSString* background_path = [background_folder stringByAppendingPathComponent:background_files.firstObject];
		[[@"invalid image" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:background_path atomically:YES];
		cache_controller = ImageCacheController(cache_months);
		WaitForImage(cache_controller, background_url);
		NSCAssert(atomic_load(&image_request_count) == 3, @"Corrupt cached images must be downloaded again");
		[(NSCache *)[cache_controller valueForKey:@"images"] removeAllObjects];
		WaitForImage(cache_controller, background_url);
		NSCAssert(atomic_load(&image_request_count) == 3, @"Memory eviction must fall back to disk without downloading");
		[[NSFileManager defaultManager] removeItemAtPath:image_cache_root error:nil];

		method_exchangeImplementations(class_getInstanceMethod(NSWorkspace.class, @selector(openURL:)), class_getInstanceMethod(NSWorkspace.class, @selector(calendarTestOpenURL:)));
		MBCalendarMonthView* month_view = [MBCalendarMonthView new];
		for (NSNumber* height in @[ @100, @200 ]) {
			NSImage* cover = [NSImage imageWithSize:NSMakeSize(100, height.doubleValue) flipped:NO drawingHandler:^BOOL(NSRect rect) {
				[[NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1] setFill];
				NSRectFill(rect);
				return YES;
			}];
			NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:100 pixelsHigh:128 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
			[[NSColor whiteColor] setFill];
			NSRectFill(NSMakeRect(0, 0, 100, 128));
			[month_view drawImage:cover inRect:NSMakeRect(10, 12, 64, 104) fill:NO dimmed:YES];
			[NSGraphicsContext restoreGraphicsState];
			NSInteger corner_x = height.integerValue == 100 ? 10 : 16;
			NSInteger corner_y = height.integerValue == 100 ? 32 : 12;
			NSCAssert([bitmap colorAtX:corner_x y:corner_y].greenComponent > 0.9 && [bitmap colorAtX:42 y:64].greenComponent < 0.1, @"Square and tall covers must round their actual fitted corners without cropping the center");
			NSCAssert([bitmap colorAtX:42 y:64].redComponent > 0.75 && [bitmap colorAtX:42 y:64].redComponent < 0.9, @"Selected cover must receive a dark overlay confined to the rounded image");
		}
		NSDictionary* book = @{ @"title": @"A Finished Book", @"author": @"An Author", @"day": @2, @"finished_label": @"Oct 2", @"page_count": @384 };
		NSDictionary* fixture = @{ @"months": @[ @{ @"year": @2026, @"month": @10, @"books": @[ book ], @"book_count": @1, @"page_count": @384, @"background_color": @"#d2a530" } ] };
		if (argc > 2) {
			NSData* data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
			fixture = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		}
		NSCAssert(fixture != nil, @"Fixture must parse");
		NSArray* months = [MBCalendarController monthsFromResponse:fixture];
		NSCAssert(months.count > 0, @"Fixture must contain calendar months");
		month_view.month = months.firstObject;
		NSString* first_title = [months.firstObject[@"books"] firstObject][@"title"];
		NSCAssert(month_view.accessibilityElement && [month_view.accessibilityRole isEqual:NSAccessibilityGroupRole] && [month_view.accessibilityLabel containsString:first_title], @"Extracted month view must retain its accessible book description");
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
		NSCAssert(![controller tableView:table shouldSelectRow:0] && table.menu == nil, @"Whole month cards must not be selected by the table");
		NSWindow* click_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 700) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
		click_window.contentViewController = controller;
		NSDictionary* linked_book = @{ @"title": @"First book", @"isbn": @"9781250462657" };
		NSDictionary* missing_isbn_book = @{ @"title": @"Second book", @"isbn": NSNull.null };
		NSArray* click_months = @[
			@{ @"year": @2026, @"month": @10, @"books": @[ linked_book, missing_isbn_book ] },
			@{ @"year": @2026, @"month": @9, @"books": @[ linked_book ] }
		];
		[controller setValue:click_months forKey:@"months"];
		[table reloadData];
		[click_window.contentView layoutSubtreeIfNeeded];
		MBCalendarMonthView* first_month = [table viewAtColumn:0 row:0 makeIfNecessary:YES];
		NSCAssert([first_month bookIndexAtPoint:NSMakePoint(30, 116)] == 0 && [first_month bookIndexAtPoint:NSMakePoint(30, 260)] == 1, @"Each book must have an independent hit region");
		NSCAssert([first_month bookIndexAtPoint:NSMakePoint(30, 115)] == NSNotFound && [first_month bookIndexAtPoint:NSMakePoint(10, 150)] == NSNotFound && [first_month bookIndexAtPoint:NSMakePoint(30, 404)] == NSNotFound, @"Headers, outer insets, and space after books must not select a book");
		ClickMonth(table, 0, NSMakePoint(30, 150), 1);
		NSCAssert(first_month.selectedBookIndex == 0 && opened_urls.count == 0, @"Single clicks must select without opening the browser");
		ClickMonth(table, 0, NSMakePoint(300, 300), 1);
		NSCAssert(first_month.selectedBookIndex == 1, @"Clicking the text portion must select the second book");
		ClickMonth(table, 0, NSMakePoint(300, 300), 2);
		NSCAssert(opened_urls.count == 0, @"Missing ISBN must not open a browser page");
		ClickMonth(table, 1, NSMakePoint(30, 150), 1);
		MBCalendarMonthView* second_month = [table viewAtColumn:0 row:1 makeIfNecessary:YES];
		NSCAssert(first_month.selectedBookIndex == NSNotFound && second_month.selectedBookIndex == 0, @"Only one book across all months may be selected");
		ClickMonth(table, 1, NSMakePoint(30, 150), 2);
		NSCAssert(opened_urls.count == 1 && [[opened_urls.lastObject absoluteString] isEqual:@"https://micro.blog/books/9781250462657"], @"Double clicks must open the ISBN page using the normal browser flow");
		ClickMonth(table, 1, NSMakePoint(30, 80), 2);
		NSCAssert(second_month.selectedBookIndex == NSNotFound && opened_urls.count == 1, @"Clicking a month header must clear selection without opening a book");
		ClickMonthWithModifiers(table, 0, NSMakePoint(30, 150), 1, NSEventModifierFlagCommand);
		NSCAssert(first_month.selectedBookIndex == 0, @"Command-click on an unselected book must select it");
		ClickMonthWithModifiers(table, 0, NSMakePoint(300, 300), 1, NSEventModifierFlagCommand);
		NSCAssert(first_month.selectedBookIndex == 1, @"Command-click on a different book must move the selection");
		ClickMonthWithModifiers(table, 0, NSMakePoint(300, 300), 1, NSEventModifierFlagCommand);
		NSCAssert(first_month.selectedBookIndex == NSNotFound && [controller valueForKey:@"selectedBookIndexPath"] == nil && opened_urls.count == 1, @"Command-click on the selected book must deselect it without opening a browser");

		NSDictionary* empty_month = @{ @"year": @2026, @"month": @8, @"books": @[] };
		NSArray* keyboard_months = @[ empty_month, click_months[0], empty_month, click_months[1], empty_month ];
		[controller setValue:keyboard_months forKey:@"months"];
		[table reloadData];
		[click_window setContentSize:NSMakeSize(600, 200)];
		[click_window.contentView layoutSubtreeIfNeeded];
		[controller focusContent];
		NSCAssert(click_window.firstResponder == table, @"Calendar focus must go to its keyboard-enabled table");
		PressKey(table, NSUpArrowFunctionKey, 0);
		PressKey(table, '\r', 0);
		NSCAssert([controller valueForKey:@"selectedBookIndexPath"] == nil && opened_urls.count == 1, @"Up and Return without selection must not select or open a book");
		PressKey(table, NSDownArrowFunctionKey, 0);
		AssertSelection(controller, 1, 0);
		PressKey(table, NSUpArrowFunctionKey, 0);
		AssertSelection(controller, 1, 0);
		PressKey(table, '\r', 0);
		NSCAssert(opened_urls.count == 2 && [[opened_urls.lastObject absoluteString] isEqual:@"https://micro.blog/books/9781250462657"], @"Return must open the same URL as double-click");
		PressKey(table, NSDownArrowFunctionKey, 0);
		AssertSelection(controller, 1, 1);
		PressKey(table, '\r', 0);
		NSCAssert(opened_urls.count == 2, @"Return on a book without ISBN must not open a browser");
		PressKey(table, NSDownArrowFunctionKey, 0);
		AssertSelection(controller, 3, 0);
		NSRect selected_rect = [table rectOfRow:3];
		selected_rect.origin.y += 116;
		selected_rect.size.height = 144;
		NSCAssert(NSContainsRect(table.visibleRect, selected_rect), @"Keyboard navigation must scroll the individual book into view");
		PressKey(table, NSDownArrowFunctionKey, 0);
		AssertSelection(controller, 3, 0);
		PressKey(table, NSUpArrowFunctionKey, 0);
		AssertSelection(controller, 1, 1);
		PressKey(table, NSUpArrowFunctionKey, 0);
		AssertSelection(controller, 1, 0);
		PressKey(table, NSDownArrowFunctionKey, NSEventModifierFlagCommand);
		AssertSelection(controller, 1, 0);
		NSCAssert(fabs(NSMaxY(table.visibleRect) - NSHeight(table.bounds)) < 1, @"Command–Down must scroll to the bottom without changing selection");
		PressKey(table, NSUpArrowFunctionKey, NSEventModifierFlagCommand);
		NSCAssert(NSMinY(table.visibleRect) == 0, @"Command–Up must scroll to the top");
		[controller setValue:nil forKey:@"selectedBookIndexPath"];
		[controller setValue:@[ empty_month ] forKey:@"months"];
		[table reloadData];
		PressKey(table, NSDownArrowFunctionKey, 0);
		NSCAssert([controller valueForKey:@"selectedBookIndexPath"] == nil, @"An empty calendar must not select nonexistent books");

		[controller setValue:months forKey:@"months"];
		[table reloadData];
		click_window.contentViewController = nil;
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
			NSCAssert(window.firstResponder == [calendar valueForKey:@"tableView"], @"Switching to Calendar must allow Down to select the first book without clicking first");
			NSUInteger calendar_request = requests.count - 1;
			tabs.selectedSegment = 0;
			[shelves selectTab:tabs];
			tabs.selectedSegment = 1;
			[shelves selectTab:tabs];
			NSCAssert(requests.count == calendar_request + 1 && calendar.loading, @"Switching tabs during the first load must reuse the pending request");
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
			[window setContentSize:NSMakeSize(700, 720)];
			Pump();
			NSTableView* calendar_table = [calendar valueForKey:@"tableView"];
			ClickMonth(calendar_table, 0, NSMakePoint(30, 150), 1);
			Render(window.contentView, @"/private/tmp/microblog-calendar-selected.png");
			MBCalendarMonthView* selected_cell = [calendar_table viewAtColumn:0 row:0 makeIfNecessary:YES];
			NSBitmapImageRep* selected_pixels = Render(selected_cell, @"/private/tmp/microblog-calendar-selected-month.png");
			CGFloat scale = selected_pixels.pixelsWide / NSWidth(selected_cell.bounds);
			NSColor* selected_color = [[selected_pixels colorAtX:20 * scale y:150 * scale] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
			NSCAssert(selected_color.redComponent > 0.9 && selected_color.redComponent < 0.99, @"Selected book background must be light gray, not white");
			[window setContentSize:NSMakeSize(700, 300)];
			Pump();
			PressKey(calendar_table, NSDownArrowFunctionKey, NSEventModifierFlagCommand);
			NSPoint scroll_position = calendar_table.visibleRect.origin;
			NSUInteger request_count = requests.count;
			tabs.selectedSegment = 0;
			[shelves selectTab:tabs];
			NSCAssert(!shelves.tableView.enclosingScrollView.hidden && calendar.view.hidden, @"Toggle must restore the existing shelf view");
			tabs.selectedSegment = 1;
			[shelves selectTab:tabs];
			NSCAssert([shelves valueForKey:@"calendarController"] == calendar, @"Repeated toggles must reuse the existing calendar controller");
			Pump();
			NSCAssert(requests.count == request_count && !calendar.loading, @"Returning to Calendar must not refresh it");
			AssertSelection(calendar, 0, 0);
			NSCAssert(NSEqualPoints(calendar_table.visibleRect.origin, scroll_position), @"Tab switches must preserve calendar scroll position");
			[shelves refresh];
			NSCAssert(calendar.loading && [requests[request_count][@"path"] isEqual:@"/books/calendar"], @"Explicit refresh must still reload the calendar");
			Reply(request_count, 200, fixture);
			Reply(request_count + 1, 200, goals_fixture);
			NSCAssert([calendar valueForKey:@"selectedBookIndexPath"] == nil, @"Reloading must clear index-based book selection");
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
		NSDictionary* ordinary_page = @{ @"properties": @{ @"content": @[ @"An ordinary page." ] } };
		NSDictionary* calendar_page = @{ @"properties": @{ @"content": @[ @"Intro\n{{< bookcalendar view=\"list\" >}}" ] } };
		NSCAssert(([MBCalendarController responseContainsCalendarPage:@{ @"items": @[ ordinary_page, calendar_page ] }].boolValue), @"Calendar shortcode anywhere in source text must be detected");
		NSCAssert([MBCalendarController responseContainsCalendarPage:@{ @"items": @[ @{ @"properties": @{ @"content": @[ @{ @"text": @"{{< bookcalendar >}}" } ] } } ] }].boolValue, @"Object-form Micropub content must be supported");
		NSCAssert([MBCalendarController responseContainsCalendarPage:@{ @"items": @[ NSNull.null ] }] == nil, @"Malformed source responses must not offer a duplicate page");
		CalendarPageTestController* page_controller = [CalendarPageTestController new];
		NSWindow* page_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 500) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
		page_window.contentViewController = page_controller;
		[page_controller setValue:months forKey:@"months"];
		NSTableView* page_table = [page_controller valueForKey:@"tableView"];
		[page_table reloadData];
		[page_controller checkCalendarPage];
		NSDictionary* page_request = page_requests.lastObject;
		NSCAssert([page_request[@"args"][@"q"] isEqual:@"source"] && [page_request[@"args"][@"mp-channel"] isEqual:@"pages"] && [page_request[@"args"][@"mp-destination"] isEqual:destination_uid], @"Page checks must use source/pages for the selected blog");
		NSView* publish_header = [page_controller valueForKey:@"publishHeader"];
		NSButton* publish_button = [page_controller valueForKey:@"publishButton"];
		NSProgressIndicator* publish_spinner = [page_controller valueForKey:@"publishSpinner"];
		NSLayoutConstraint* header_height = [page_controller valueForKey:@"publishHeaderHeightConstraint"];
		NSCAssert(publish_header.hidden && header_height.constant == 0, @"Header must stay collapsed until every page has been checked");
		ReplyRequest(page_request, 200, @{ @"items": @[ calendar_page ] });
		NSCAssert(publish_header.hidden, @"Existing calendar pages must suppress the publication header");

		[page_controller checkCalendarPage];
		ReplyRequest(page_requests.lastObject, 502, nil);
		NSCAssert(publish_header.hidden, @"Page lookup failures must not offer to create duplicates");
		[page_controller checkCalendarPage];
		NSMutableArray* many_pages = [NSMutableArray array];
		for (NSInteger i = 0; i < 100; i++) {
			[many_pages addObject:ordinary_page];
		}
		ReplyRequest(page_requests.lastObject, 200, @{ @"items": many_pages });
		NSCAssert(publish_header.hidden && [page_requests.lastObject[@"args"][@"offset"] integerValue] == 100, @"Full source batches must fetch the next page before showing the header");
		ReplyRequest(page_requests.lastObject, 200, @{ @"items": @[ calendar_page ] });
		NSCAssert(publish_header.hidden, @"A calendar shortcode in later source batches must also suppress the header");
		[page_controller checkCalendarPage];
		ReplyRequest(page_requests.lastObject, 200, @{ @"items": @[ ordinary_page ] });
		NSCAssert(!publish_header.hidden && header_height.constant == 48 && publish_button.enabled, @"Checked blogs without a calendar page must show the publication header");
		NSTextField* publish_label = [page_controller valueForKey:@"publishLabel"];
		NSCAssert([publish_label.stringValue isEqual:@"Publish calendar as a page on calendar.test?"], @"Publication prompt must name the selected blog");
		[page_window orderFront:nil];
		Pump();
		for (NSNumber* width in @[ @700, @440 ]) {
			[page_window setContentSize:NSMakeSize(width.doubleValue, 500)];
			Pump();
			[page_window.contentView layoutSubtreeIfNeeded];
			NSCAssert(NSMaxX(publish_label.frame) <= NSMinX(publish_spinner.frame) - 11 && NSMaxX(publish_button.frame) <= NSWidth(publish_header.bounds) - 15, @"Header label, spinner, and button must not overlap on narrow windows");
			Render(page_window.contentView, [NSString stringWithFormat:@"/private/tmp/microblog-calendar-publish-%@.png", width]);
		}
		page_window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
		Pump();
		Render(page_window.contentView, @"/private/tmp/microblog-calendar-publish-dark.png");
		page_window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
		Pump();

		ClickMonth(page_table, 0, NSMakePoint(30, 150), 1);
		NSUInteger page_post_count = page_posts.count;
		[page_controller addCalendarPage:nil];
		[page_controller addCalendarPage:nil];
		NSDictionary* page_post = page_posts.lastObject;
		NSCAssert(page_posts.count == page_post_count + 1 && !publish_button.enabled && !publish_spinner.hidden, @"Publishing must disable Add Page, show its spinner, and reject duplicate clicks");
		NSCAssert([page_post[@"path"] isEqual:@"/micropub"] && [page_post[@"params"][@"name"] isEqual:@"Book calendar"] && [page_post[@"params"][@"content"] isEqual:@"{{< bookcalendar view=\"list\" >}}"] && [page_post[@"params"][@"mp-channel"] isEqual:@"pages"] && [page_post[@"params"][@"mp-destination"] isEqual:destination_uid], @"Page creation must match the existing standalone Pages contract");
		ReplyRequest(page_post, 400, @{ @"error": @"invalid_request", @"error_description": @"Please try again." });
		NSCAssert(publish_button.enabled && !publish_header.hidden && publish_spinner.hidden && [last_page_error isEqual:@"Please try again."], @"Failed publication must stop the spinner, retain the header, and allow retry with an error message");
		__block NSInteger page_refresh_notifications = 0;
		id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kClosePostingNotification object:page_controller queue:nil usingBlock:^(NSNotification* notification) {
			page_refresh_notifications++;
		}];
		[page_controller addCalendarPage:nil];
		ReplyRequest(page_posts.lastObject, 202, @{ @"url": @"https://calendar.test/book-calendar/" });
		NSCAssert(!publish_button.enabled && page_refresh_notifications == 1, @"Successful publication must keep Add Page disabled during the collapse and refresh the Pages pane");
		for (NSInteger i = 0; i < 10 && !publish_header.hidden; i++) {
			Pump();
		}
		NSCAssert(publish_header.hidden && header_height.constant == 0 && publish_spinner.hidden, @"Successful publication must hide the header after its collapse animation");
		AssertSelection(page_controller, 0, 0);
		[[NSNotificationCenter defaultCenter] removeObserver:observer];

		[page_controller checkCalendarPage];
		NSDictionary* stale_page_request = page_requests.lastObject;
		destination_uid = @"other-destination";
		blog_hostname = @"other.test";
		[page_controller checkCalendarPage];
		NSDictionary* current_page_request = page_requests.lastObject;
		ReplyRequest(stale_page_request, 200, @{ @"items": @[] });
		NSCAssert(publish_header.hidden, @"Source responses for an old destination must be ignored");
		ReplyRequest(current_page_request, 200, @{ @"items": @[] });
		NSCAssert([publish_label.stringValue containsString:@"other.test"], @"Changing blogs must update the publication hostname");
		destination_uid = @"third-destination";
		page_post_count = page_posts.count;
		[page_controller addCalendarPage:nil];
		NSCAssert(page_posts.count == page_post_count && publish_header.hidden, @"A blog change before Add Page must trigger a new check, not publish to the wrong blog");
		has_hosted_blog = NO;
		NSUInteger page_request_count = page_requests.count;
		[page_controller checkCalendarPage];
		NSCAssert(page_requests.count == page_request_count && publish_header.hidden, @"Accounts without a hosted blog must not be offered a shortcode page");
		has_hosted_blog = YES;
		destination_uid = @"test-destination";
		blog_hostname = @"calendar.test";
		[page_window orderOut:nil];
		NSLog(@"Passed calendar parsing, lifecycle, selection, disk caching, standalone page publishing, and optional bookshelf layout/toggle checks.");
	}
	return 0;
}
