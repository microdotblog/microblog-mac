#import "MBCalendarController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "MBCalendarMonthView.h"

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
	return cell;
}

@end
