#import "MBCalendarController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "MBCalendarMonthView.h"
#import "MBBook.h"
#import <CommonCrypto/CommonDigest.h>

static NSInteger CalendarNumber(id value)
{
	return [value isKindOfClass:[NSNumber class]] ? MAX(0, [value integerValue]) : 0;
}

@interface MBCalendarController () <NSTableViewDataSource, NSTableViewDelegate>
@property (strong, nonatomic) NSTableView* tableView;
@property (strong, nonatomic) NSTextField* messageLabel;
@property (strong, nonatomic) NSButton* retryButton;
@property (strong, nonatomic) NSArray* months;
@property (strong, nonatomic) NSCache* images;
@property (strong, nonatomic) NSMutableSet* requestedImages;
@property (strong, nonatomic) NSURLSession* imageSession;
@property (assign, nonatomic) NSUInteger loadGeneration;
@property (assign, nonatomic, readwrite) BOOL loading;
@property (strong, nonatomic) NSIndexPath* selectedBookIndexPath;

- (void) calendarMouseDown:(NSEvent *)event;
- (BOOL) calendarKeyDown:(NSEvent *)event;
@end

// Keep native scrolling, but select a book inside the month rather than the whole card.
@interface MBCalendarTableView : NSTableView
@end

@implementation MBCalendarTableView

- (void) mouseDown:(NSEvent *)event
{
	[(MBCalendarController *)self.delegate calendarMouseDown:event];
}

- (void) keyDown:(NSEvent *)event
{
	if (![(MBCalendarController *)self.delegate calendarKeyDown:event]) {
		[super keyDown:event];
	}
}

@end

@implementation MBCalendarController

- (void) loadView
{
	self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 500)];
	self.months = @[];
	self.images = [[NSCache alloc] init];
	self.images.countLimit = 200;
	self.requestedImages = [NSMutableSet set];

	NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	configuration.HTTPCookieStorage = nil;
	configuration.HTTPShouldSetCookies = NO;
	configuration.timeoutIntervalForRequest = 30;
	self.imageSession = [NSURLSession sessionWithConfiguration:configuration];

	NSScrollView* scroll_view = [[NSScrollView alloc] initWithFrame:self.view.bounds];
	scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
	scroll_view.hasVerticalScroller = YES;
	scroll_view.autohidesScrollers = YES;
	scroll_view.borderType = NSNoBorder;

	self.tableView = [[MBCalendarTableView alloc] initWithFrame:scroll_view.bounds];
	self.tableView.headerView = nil;
	self.tableView.style = NSTableViewStyleFullWidth;
	self.tableView.intercellSpacing = NSZeroSize;
	self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
	self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
	self.tableView.autoresizingMask = NSViewWidthSizable;
	self.tableView.backgroundColor = [NSColor controlBackgroundColor];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;

	NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"Month"];
	column.width = 600;
	column.minWidth = 0;
	column.maxWidth = CGFLOAT_MAX;
	[self.tableView addTableColumn:column];

	scroll_view.documentView = self.tableView;
	[self.view addSubview:scroll_view];

	self.messageLabel = [NSTextField wrappingLabelWithString:@""];
	self.messageLabel.alignment = NSTextAlignmentCenter;
	self.messageLabel.textColor = [NSColor secondaryLabelColor];
	self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:self.messageLabel];

	self.retryButton = [NSButton buttonWithTitle:@"Retry" target:self action:@selector(retryLoading:)];
	self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
	self.retryButton.hidden = YES;
	[self.view addSubview:self.retryButton];

	[NSLayoutConstraint activateConstraints:@[
		[scroll_view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[scroll_view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[scroll_view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

		[self.messageLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60],
		[self.messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
		[self.messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

		[self.retryButton.topAnchor constraintEqualToAnchor:self.messageLabel.bottomAnchor constant:12],
		[self.retryButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
	]];
}

- (void) dealloc
{
	[self.imageSession invalidateAndCancel];
}

+ (NSArray *) monthsFromResponse:(id)response
{
	if (![response isKindOfClass:[NSDictionary class]] || ![response[@"months"] isKindOfClass:[NSArray class]]) {
		return nil;
	}

	NSMutableArray* months = [NSMutableArray array];
	for (id item in response[@"months"]) {
		if (![item isKindOfClass:[NSDictionary class]] || CalendarNumber(item[@"year"]) == 0 || CalendarNumber(item[@"month"]) < 1 || CalendarNumber(item[@"month"]) > 12 || ![item[@"books"] isKindOfClass:[NSArray class]]) {
			continue;
		}

		NSMutableDictionary* month = [item mutableCopy];
		NSMutableArray* books = [NSMutableArray array];
		for (id book in item[@"books"]) {
			if ([book isKindOfClass:[NSDictionary class]]) {
				[books addObject:book];
			}
		}

		month[@"books"] = books;
		if (![month[@"book_count"] isKindOfClass:[NSNumber class]]) {
			month[@"book_count"] = @(books.count);
		}
		[months addObject:month];
	}

	return months;
}

- (void) setLoading:(BOOL)loading
{
	_loading = loading;
	if (self.loadingDidChange) {
		self.loadingDidChange();
	}
}

- (void) reloadCalendar
{
	[self view];
	NSUInteger generation = ++self.loadGeneration;
	NSString* username = [RFSettings stringForKey:kAccountUsername];

	self.messageLabel.hidden = YES;
	self.retryButton.hidden = YES;
	self.loading = YES;

	RFClient* client = [[RFClient alloc] initWithPath:@"/books/calendar"];
	__weak MBCalendarController* weak_self = self;
	[client getWithCompletion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			MBCalendarController* controller = weak_self;
			if (!controller || generation != controller.loadGeneration) {
				return;
			}

			controller.loading = NO;
			if (![username isEqualToString:[RFSettings stringForKey:kAccountUsername]]) {
				return;
			}

			NSArray* months = [[controller class] monthsFromResponse:response.parsedResponse];
			if (response.httpError || response.httpResponse.statusCode != 200 || months == nil) {
				controller.selectedBookIndexPath = nil;
				controller.months = @[];
				[controller.tableView reloadData];
				controller.messageLabel.stringValue = @"Could not load your book calendar. Please try again.";
				controller.messageLabel.hidden = NO;
				controller.retryButton.hidden = NO;
				return;
			}

			controller.months = months;
			controller.selectedBookIndexPath = nil;
			[controller.requestedImages removeAllObjects];
			[controller.tableView reloadData];

			controller.messageLabel.stringValue = @"No finished books yet.";
			controller.messageLabel.hidden = months.count > 0;
		});
	}];
}

- (void) retryLoading:(id)sender
{
	[self reloadCalendar];
}

- (void) focusContent
{
	[self.view.window makeFirstResponder:self.tableView];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.months.count;
}

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	return 116 + [self.months[row][@"books"] count] * 144;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return NO;
}

- (void) calendarMouseDown:(NSEvent *)event
{
	[self.view.window makeFirstResponder:self.tableView];
	NSPoint point = [self.tableView convertPoint:event.locationInWindow fromView:nil];
	NSInteger row = [self.tableView rowAtPoint:point];
	MBCalendarMonthView* cell = row >= 0 ? [self.tableView viewAtColumn:0 row:row makeIfNecessary:YES] : nil;
	NSInteger book_index = cell ? [cell bookIndexAtPoint:[cell convertPoint:event.locationInWindow fromView:nil]] : NSNotFound;

	NSIndexPath* index_path = book_index != NSNotFound ? [[NSIndexPath indexPathWithIndex:row] indexPathByAddingIndex:book_index] : nil;
	[self selectBookAtIndexPath:index_path];
	if (index_path && event.clickCount == 2) {
		[self openBook:self.months[row][@"books"][book_index]];
	}
}

- (void) selectBookAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.selectedBookIndexPath) {
		NSInteger old_row = [self.selectedBookIndexPath indexAtPosition:0];
		MBCalendarMonthView* old_cell = [self.tableView viewAtColumn:0 row:old_row makeIfNecessary:NO];
		old_cell.selectedBookIndex = NSNotFound;
	}

	self.selectedBookIndexPath = indexPath;
	if (indexPath) {
		NSInteger row = [indexPath indexAtPosition:0];
		NSInteger book_index = [indexPath indexAtPosition:1];
		MBCalendarMonthView* cell = [self.tableView viewAtColumn:0 row:row makeIfNecessary:YES];
		cell.selectedBookIndex = book_index;
	}
}

- (BOOL) calendarKeyDown:(NSEvent *)event
{
	NSString* characters = event.charactersIgnoringModifiers;
	if (characters.length == 0 || (event.modifierFlags & (NSEventModifierFlagControl | NSEventModifierFlagOption))) {
		return NO;
	}
	unichar key = [characters characterAtIndex:0];
	BOOL command = (event.modifierFlags & NSEventModifierFlagCommand) != 0;

	if (!command && (key == '\r' || key == NSEnterCharacter)) {
		if (self.selectedBookIndexPath) {
			NSInteger row = [self.selectedBookIndexPath indexAtPosition:0];
			NSInteger book_index = [self.selectedBookIndexPath indexAtPosition:1];
			[self openBook:self.months[row][@"books"][book_index]];
		}
		return YES;
	}
	if (key != NSUpArrowFunctionKey && key != NSDownArrowFunctionKey) {
		return NO;
	}

	if (command) {
		CGFloat bottom = MAX(0, NSHeight(self.tableView.bounds) - NSHeight(self.tableView.enclosingScrollView.contentView.bounds));
		[self.tableView scrollPoint:NSMakePoint(0, key == NSUpArrowFunctionKey ? 0 : bottom)];
		return YES;
	}
	if (!self.selectedBookIndexPath && key == NSUpArrowFunctionKey) {
		return YES;
	}

	NSInteger direction = key == NSDownArrowFunctionKey ? 1 : -1;
	NSInteger row = self.selectedBookIndexPath ? [self.selectedBookIndexPath indexAtPosition:0] : 0;
	NSInteger book_index = self.selectedBookIndexPath ? [self.selectedBookIndexPath indexAtPosition:1] + direction : 0;
	while (row >= 0 && row < self.months.count) {
		NSInteger book_count = [self.months[row][@"books"] count];
		if (book_index >= 0 && book_index < book_count) {
			NSIndexPath* index_path = [[NSIndexPath indexPathWithIndex:row] indexPathByAddingIndex:book_index];
			[self selectBookAtIndexPath:index_path];

			NSRect book_rect = [self.tableView rectOfRow:row];
			book_rect.origin.y += 116 + book_index * 144;
			book_rect.size.height = 144;
			[self.tableView scrollRectToVisible:book_rect];
			return YES;
		}
		row += direction;
		book_index = direction > 0 ? 0 : (row >= 0 ? (NSInteger)[self.months[row][@"books"] count] - 1 : -1);
	}

	return YES;
}

- (void) openBook:(NSDictionary *)book
{
	NSString* isbn = [book[@"isbn"] isKindOfClass:[NSString class]] ? [book[@"isbn"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
	if (isbn.length > 0) {
		NSURL* url = [[NSURL URLWithString:@"https://micro.blog/books/"] URLByAppendingPathComponent:isbn];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (NSImage *) imageForURL:(NSString *)url
{
	NSImage* image = [self.images objectForKey:url];
	NSURL* image_url = url.length ? [NSURL URLWithString:url] : nil;
	if (image || ![@[ @"https", @"http" ] containsObject:image_url.scheme.lowercaseString] || image_url.host.length == 0 || [self.requestedImages containsObject:url]) {
		return image;
	}

	[self.requestedImages addObject:url];
	BOOL background = NO;
	MBBook* cached_book = nil;
	for (NSDictionary* month in self.months) {
		if ([month[@"background_url"] isEqual:url]) {
			background = YES;
			break;
		}
		for (NSDictionary* book in month[@"books"]) {
			if ([book[@"cover_url"] isEqual:url] && [book[@"isbn"] isKindOfClass:NSString.class]) {
				cached_book = [[MBBook alloc] init];
				cached_book.isbn = book[@"isbn"];
				break;
			}
		}
	}

	__weak MBCalendarController* weak_self = self;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSString* cache_path = background ? nil : [cached_book pathForCachedCover];
		if (!cache_path) {
			NSData* url_data = [url dataUsingEncoding:NSUTF8StringEncoding];
			unsigned char digest[CC_SHA256_DIGEST_LENGTH];
			CC_SHA256(url_data.bytes, (CC_LONG)url_data.length, digest);
			NSMutableString* filename = [NSMutableString string];
			for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
				[filename appendFormat:@"%02x", digest[i]];
			}
			[filename appendString:@".tif"];
			cache_path = [MBBook pathForCachedImage:filename inFolder:background ? @"Book Backgrounds" : @"Book Covers"];
		}

		NSImage* cached_image = cache_path ? [[NSImage alloc] initWithContentsOfFile:cache_path] : nil;
		if (cached_image.isValid) {
			[weak_self displayImage:cached_image forURL:url];
			return;
		}

		[[weak_self.imageSession dataTaskWithURL:image_url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
			NSImage* downloaded = !error && [(NSHTTPURLResponse *)response statusCode] == 200 && data.length < 15 * 1024 * 1024 ? [[NSImage alloc] initWithData:data] : nil;
			if (downloaded.isValid) {
				NSData* cache_data = downloaded.TIFFRepresentation;
				if (cache_path) {
					[cache_data writeToFile:cache_path atomically:YES];
				}
				[weak_self displayImage:downloaded forURL:url];
			}
		}] resume];
	});

	return nil;
}

- (void) displayImage:(NSImage *)image forURL:(NSString *)url
{
	RFDispatchMainAsync(^{
		[self.images setObject:image forKey:url];
		[self.requestedImages removeObject:url];

		// Repaint visible cards without rebuilding the table or moving its scroll position.
		self.tableView.needsDisplay = YES;
		for (NSView* row_view in self.tableView.subviews) {
			for (NSView* cell in row_view.subviews) {
				cell.needsDisplay = YES;
			}
		}
	});
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	MBCalendarMonthView* cell = [tableView makeViewWithIdentifier:@"Month" owner:self];
	if (!cell) {
		cell = [[MBCalendarMonthView alloc] initWithFrame:NSZeroRect];
		cell.identifier = @"Month";
	}

	cell.month = self.months[row];
	cell.selectedBookIndex = self.selectedBookIndexPath && [self.selectedBookIndexPath indexAtPosition:0] == row ? [self.selectedBookIndexPath indexAtPosition:1] : NSNotFound;

	__weak MBCalendarController* weak_self = self;
	cell.imageForURL = ^NSImage* (NSString* url) {
		return [weak_self imageForURL:url];
	};

	return cell;
}

@end
