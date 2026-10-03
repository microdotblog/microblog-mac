#import "MBCalendarController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "NSColor+Extras.h"

static NSString* CalendarString(id value)
{
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSInteger CalendarNumber(id value)
{
	return [value isKindOfClass:[NSNumber class]] ? MAX(0, [value integerValue]) : 0;
}

static NSString* CalendarMonthName(NSDictionary* month, BOOL abbreviated)
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	NSArray* names = abbreviated ? formatter.shortMonthSymbols : formatter.monthSymbols;
	return names[CalendarNumber(month[@"month"]) - 1];
}

static NSString* CalendarBookDetails(NSDictionary* book)
{
	NSMutableArray* parts = [NSMutableArray array];
	NSString* finished = CalendarString(book[@"finished_label"]);
	if (finished.length) {
		[parts addObject:[@"Finished " stringByAppendingString:finished]];
	}
	NSInteger pages = CalendarNumber(book[@"page_count"]);
	if (pages > 0) {
		[parts addObject:[NSString stringWithFormat:@"%ld %@", (long)pages, pages == 1 ? @"page" : @"pages"]];
	}
	return [parts componentsJoinedByString:@" · "];
}

// One reusable, read-only card per month. Images are supplied by the controller's cache.
@interface MBCalendarMonthView : NSTableCellView
@property (strong, nonatomic) NSDictionary* month;
@property (copy, nonatomic) NSImage* (^imageForURL)(NSString* url);
@end

@implementation MBCalendarMonthView

- (BOOL) isFlipped
{
	return YES;
}

- (void) drawText:(NSString *)text inRect:(NSRect)rect font:(NSFont *)font color:(NSColor *)color alignment:(NSTextAlignment)alignment
{
	NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
	style.alignment = alignment;
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	[text drawInRect:rect withAttributes:@{
		NSFontAttributeName: font,
		NSForegroundColorAttributeName: color,
		NSParagraphStyleAttributeName: style
	}];
}

- (void) drawImage:(NSImage *)image inRect:(NSRect)rect fill:(BOOL)shouldFill
{
	if (!image.isValid || image.size.width <= 0 || image.size.height <= 0) {
		return;
	}
	NSRect source = NSMakeRect(0, 0, image.size.width, image.size.height);
	if (shouldFill) {
		CGFloat scale = MAX(rect.size.width / source.size.width, rect.size.height / source.size.height);
		NSSize crop = NSMakeSize(rect.size.width / scale, rect.size.height / scale);
		source = NSMakeRect((source.size.width - crop.width) / 2, (source.size.height - crop.height) / 2, crop.width, crop.height);
	}
	else {
		CGFloat scale = MIN(rect.size.width / source.size.width, rect.size.height / source.size.height);
		NSSize size = NSMakeSize(source.size.width * scale, source.size.height * scale);
		rect = NSMakeRect(NSMidX(rect) - size.width / 2, NSMidY(rect) - size.height / 2, size.width, size.height);
	}
	[image drawInRect:rect fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}

- (void) drawRect:(NSRect)dirtyRect
{
	NSRect card = NSMakeRect(16, 16, MAX(1, self.bounds.size.width - 32), self.bounds.size.height - 16);
	NSBezierPath* outline = [NSBezierPath bezierPathWithRoundedRect:card xRadius:10 yRadius:10];
	[NSGraphicsContext saveGraphicsState];
	[outline addClip];
	[[NSColor textBackgroundColor] setFill];
	NSRectFill(card);
	NSRect header = NSMakeRect(card.origin.x, card.origin.y, card.size.width, 100);
	NSString* color = CalendarString(self.month[@"background_color"]);
	NSColor* background = color.length ? [NSColor mb_colorFromString:color] : [NSColor darkGrayColor];
	[background setFill];
	NSRectFill(header);
	[self drawImage:self.imageForURL(CalendarString(self.month[@"background_url"])) inRect:header fill:YES];
	[[NSColor colorWithWhite:0 alpha:0.45] setFill];
	NSRectFillUsingOperation(header, NSCompositingOperationSourceOver);
	NSString* heading = [NSString stringWithFormat:@"%@ %ld", CalendarMonthName(self.month, NO).uppercaseString, (long)CalendarNumber(self.month[@"year"])];
	NSInteger count = CalendarNumber(self.month[@"book_count"]);
	NSInteger pages = CalendarNumber(self.month[@"page_count"]);
	NSString* summary = [NSString stringWithFormat:@"%ld %@ · %ld %@", (long)count, count == 1 ? @"book" : @"books", (long)pages, pages == 1 ? @"page" : @"pages"];
	[self drawText:heading inRect:NSMakeRect(card.origin.x + 24, card.origin.y + 22, card.size.width - 48, 30) font:[NSFont boldSystemFontOfSize:22] color:NSColor.whiteColor alignment:NSTextAlignmentLeft];
	[self drawText:summary inRect:NSMakeRect(card.origin.x + 24, card.origin.y + 60, card.size.width - 48, 20) font:[NSFont systemFontOfSize:13] color:NSColor.whiteColor alignment:NSTextAlignmentLeft];
	NSArray* books = self.month[@"books"];
	NSString* short_month = CalendarMonthName(self.month, YES).uppercaseString;
	for (NSUInteger i = 0; i < books.count; i++) {
		NSDictionary* book = books[i];
		CGFloat top = NSMaxY(header) + i * 144;
		CGFloat date_width = card.size.width < 450 ? 54 : 76;
		CGFloat cover_left = card.origin.x + date_width + 16;
		CGFloat text_left = cover_left + 64 + 20;
		CGFloat text_width = MAX(1, NSMaxX(card) - text_left - 20);
		[[NSColor separatorColor] setFill];
		NSRectFillUsingOperation(NSMakeRect(card.origin.x + date_width, top, 1, 144), NSCompositingOperationSourceOver);
		if (i > 0) {
			NSRectFillUsingOperation(NSMakeRect(card.origin.x, top, card.size.width, 1), NSCompositingOperationSourceOver);
		}
		[self drawText:short_month inRect:NSMakeRect(card.origin.x, top + 44, date_width, 20) font:[NSFont systemFontOfSize:12] color:NSColor.secondaryLabelColor alignment:NSTextAlignmentCenter];
		NSInteger day = CalendarNumber(book[@"day"]);
		NSString* day_string = day > 0 && day <= 31 ? [NSString stringWithFormat:@"%ld", (long)day] : @"";
		[self drawText:day_string inRect:NSMakeRect(card.origin.x, top + 64, date_width, 36) font:[NSFont systemFontOfSize:26] color:NSColor.labelColor alignment:NSTextAlignmentCenter];
		NSRect cover_rect = NSMakeRect(cover_left, top + 20, 64, 104);
		[NSGraphicsContext saveGraphicsState];
		[[NSBezierPath bezierPathWithRoundedRect:cover_rect xRadius:3 yRadius:3] addClip];
		[self drawImage:self.imageForURL(CalendarString(book[@"cover_url"])) inRect:cover_rect fill:NO];
		[NSGraphicsContext restoreGraphicsState];
		NSString* title = CalendarString(book[@"title"]);
		[self drawText:title inRect:NSMakeRect(text_left, top + 28, text_width, 44) font:[NSFont boldSystemFontOfSize:16] color:NSColor.labelColor alignment:NSTextAlignmentLeft];
		[self drawText:CalendarString(book[@"author"]) inRect:NSMakeRect(text_left, top + 76, text_width, 18) font:[NSFont systemFontOfSize:13] color:NSColor.secondaryLabelColor alignment:NSTextAlignmentLeft];
		[self drawText:CalendarBookDetails(book) inRect:NSMakeRect(text_left, top + 104, text_width, 18) font:[NSFont systemFontOfSize:12] color:NSColor.secondaryLabelColor alignment:NSTextAlignmentLeft];
	}
	[NSGraphicsContext restoreGraphicsState];
	[[NSColor separatorColor] setStroke];
	outline.lineWidth = 0.5;
	[outline stroke];
}

@end

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
	self.tableView = [[NSTableView alloc] initWithFrame:scroll_view.bounds];
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
				controller.months = @[];
				[controller.tableView reloadData];
				controller.messageLabel.stringValue = @"Could not load your book calendar. Please try again.";
				controller.messageLabel.hidden = NO;
				controller.retryButton.hidden = NO;
				return;
			}
			controller.months = months;
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

- (NSImage *) imageForURL:(NSString *)url
{
	NSImage* image = [self.images objectForKey:url];
	NSURL* image_url = url.length ? [NSURL URLWithString:url] : nil;
	if (image || ![@[ @"https", @"http" ] containsObject:image_url.scheme.lowercaseString] || image_url.host.length == 0 || [self.requestedImages containsObject:url]) {
		return image;
	}
	[self.requestedImages addObject:url];
	__weak MBCalendarController* weak_self = self;
	[[self.imageSession dataTaskWithURL:image_url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
		NSImage* downloaded = !error && [(NSHTTPURLResponse *)response statusCode] == 200 && data.length < 15 * 1024 * 1024 ? [[NSImage alloc] initWithData:data] : nil;
		RFDispatchMainAsync(^{
			MBCalendarController* controller = weak_self;
			if (controller && downloaded.isValid) {
				[controller.images setObject:downloaded forKey:url];
				// Repaint visible cards without rebuilding the table or moving its scroll position.
				controller.tableView.needsDisplay = YES;
				for (NSView* row_view in controller.tableView.subviews) {
					for (NSView* cell in row_view.subviews) {
						cell.needsDisplay = YES;
					}
				}
			}
		});
	}] resume];
	return nil;
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	MBCalendarMonthView* cell = [tableView makeViewWithIdentifier:@"Month" owner:self];
	if (!cell) {
		cell = [[MBCalendarMonthView alloc] initWithFrame:NSZeroRect];
		cell.identifier = @"Month";
	}
	cell.month = self.months[row];
	__weak MBCalendarController* weak_self = self;
	cell.imageForURL = ^NSImage* (NSString* url) {
		return [weak_self imageForURL:url];
	};
	NSMutableArray* descriptions = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld", CalendarMonthName(cell.month, NO), (long)CalendarNumber(cell.month[@"year"])]];
	for (NSDictionary* book in cell.month[@"books"]) {
		[descriptions addObject:[NSString stringWithFormat:@"%@, %@, %@", CalendarString(book[@"title"]), CalendarString(book[@"author"]), CalendarBookDetails(book)]];
	}
	cell.accessibilityElement = YES;
	cell.accessibilityRole = NSAccessibilityGroupRole;
	cell.accessibilityLabel = [descriptions componentsJoinedByString:@". "];
	cell.needsDisplay = YES;
	return cell;
}

@end
