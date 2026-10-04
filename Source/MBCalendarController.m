#import "MBCalendarController.h"
#import "RFClient.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "MBCalendarMonthView.h"
#import "MBBook.h"
#import "RFConstants.h"
#import "NSError+Extras.h"
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
@property (strong, nonatomic) NSView* publishHeader;
@property (strong, nonatomic) NSTextField* publishLabel;
@property (strong, nonatomic) NSButton* publishButton;
@property (strong, nonatomic) NSProgressIndicator* publishSpinner;
@property (strong, nonatomic) NSLayoutConstraint* publishHeaderHeightConstraint;
@property (assign, nonatomic) NSUInteger pageCheckGeneration;
@property (assign, nonatomic) BOOL publishingPage;
@property (copy, nonatomic) NSString* pageUsername;
@property (copy, nonatomic) NSString* pageDestinationUID;

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

@interface MBCalendarPublishHeaderView : NSView
@end

@implementation MBCalendarPublishHeaderView

- (void) drawRect:(NSRect)dirtyRect
{
	[[NSColor textBackgroundColor] setFill];
	NSRectFill(self.bounds);

	[[NSColor separatorColor] setFill];
	NSRectFillUsingOperation(NSMakeRect(NSMinX(self.bounds), NSMinY(self.bounds), NSWidth(self.bounds), 1), NSCompositingOperationSourceOver);
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

	self.publishHeader = [[MBCalendarPublishHeaderView alloc] initWithFrame:NSZeroRect];
	self.publishHeader.translatesAutoresizingMaskIntoConstraints = NO;
	self.publishHeader.hidden = YES;
	[self.view addSubview:self.publishHeader];
	self.publishHeaderHeightConstraint = [self.publishHeader.heightAnchor constraintEqualToConstant:0];

	self.publishLabel = [NSTextField labelWithString:@""];
	self.publishLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	self.publishLabel.translatesAutoresizingMaskIntoConstraints = NO;
	[self.publishLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
	[self.publishHeader addSubview:self.publishLabel];

	self.publishButton = [NSButton buttonWithTitle:@"Add Page" target:self action:@selector(addCalendarPage:)];
	self.publishButton.translatesAutoresizingMaskIntoConstraints = NO;
	[self.publishButton setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
	[self.publishHeader addSubview:self.publishButton];

	self.publishSpinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
	self.publishSpinner.style = NSProgressIndicatorStyleSpinning;
	self.publishSpinner.controlSize = NSControlSizeSmall;
	self.publishSpinner.displayedWhenStopped = NO;
	self.publishSpinner.hidden = YES;
	self.publishSpinner.translatesAutoresizingMaskIntoConstraints = NO;
	[self.publishHeader addSubview:self.publishSpinner];

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
		[self.publishHeader.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[self.publishHeader.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[self.publishHeader.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		self.publishHeaderHeightConstraint,
		[self.publishLabel.leadingAnchor constraintEqualToAnchor:self.publishHeader.leadingAnchor constant:16],
		[self.publishLabel.centerYAnchor constraintEqualToAnchor:self.publishHeader.centerYAnchor],
		[self.publishLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.publishSpinner.leadingAnchor constant:-12],
		[self.publishSpinner.widthAnchor constraintEqualToConstant:16],
		[self.publishSpinner.heightAnchor constraintEqualToConstant:16],
		[self.publishSpinner.centerYAnchor constraintEqualToAnchor:self.publishHeader.centerYAnchor],
		[self.publishSpinner.trailingAnchor constraintEqualToAnchor:self.publishButton.leadingAnchor constant:-8],
		[self.publishButton.trailingAnchor constraintEqualToAnchor:self.publishHeader.trailingAnchor constant:-16],
		[self.publishButton.centerYAnchor constraintEqualToAnchor:self.publishHeader.centerYAnchor],

		[scroll_view.topAnchor constraintEqualToAnchor:self.publishHeader.bottomAnchor],
		[scroll_view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[scroll_view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

		[self.messageLabel.topAnchor constraintEqualToAnchor:scroll_view.topAnchor constant:60],
		[self.messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
		[self.messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

		[self.retryButton.topAnchor constraintEqualToAnchor:self.messageLabel.bottomAnchor constant:12],
		[self.retryButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
	]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
}

- (void) dealloc
{
	[self.imageSession invalidateAndCancel];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setPublishHeaderVisible:(BOOL)visible animated:(BOOL)animated
{
	if (visible) {
		self.publishHeader.hidden = NO;
	}
	if (animated) {
		[self.view layoutSubtreeIfNeeded];
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
			context.duration = 0.2;
			self.publishHeaderHeightConstraint.animator.constant = visible ? 48 : 0;
		} completionHandler:^{
			if (self.publishHeaderHeightConstraint.constant == 0) {
				self.publishHeader.hidden = YES;
			}
		}];
	}
	else {
		self.publishHeaderHeightConstraint.constant = visible ? 48 : 0;
		self.publishHeader.hidden = !visible;
	}
}

// A nil result means the response could not be checked safely.
+ (NSNumber *) responseContainsCalendarPage:(id)response
{
	if (![response isKindOfClass:NSDictionary.class] || response[@"error"] || ![response[@"items"] isKindOfClass:NSArray.class]) {
		return nil;
	}
	for (id item in response[@"items"]) {
		if (![item isKindOfClass:NSDictionary.class] || ![item[@"properties"] isKindOfClass:NSDictionary.class]) {
			return nil;
		}
		id contents = item[@"properties"][@"content"];
		if (![contents isKindOfClass:NSArray.class]) {
			return nil;
		}
		for (id content in contents) {
			NSString* text = [content isKindOfClass:NSString.class] ? content : nil;
			if ([content isKindOfClass:NSDictionary.class]) {
				text = [content[@"text"] isKindOfClass:NSString.class] ? content[@"text"] : content[@"html"];
			}
			if (![text isKindOfClass:NSString.class]) {
				return nil;
			}
			if ([text containsString:@"{{< bookcalendar"]) {
				return @YES;
			}
		}
	}
	return @NO;
}

- (BOOL) pageDestinationIsCurrent
{
	return [self.pageUsername isEqualToString:[RFSettings stringForKey:kAccountUsername]] && [self.pageDestinationUID isEqualToString:[RFSettings stringForKey:kCurrentDestinationUID] ?: @""];
}

- (void) checkCalendarPage
{
	self.pageCheckGeneration++;
	if (self.publishingPage) {
		if (![self pageDestinationIsCurrent]) {
			[self setPublishHeaderVisible:NO animated:NO];
		}
		return;
	}
	[self setPublishHeaderVisible:NO animated:NO];
	self.pageUsername = [RFSettings stringForKey:kAccountUsername];
	self.pageDestinationUID = [RFSettings stringForKey:kCurrentDestinationUID] ?: @"";
	NSString* hostname = [RFSettings stringForKey:kCurrentDestinationName];
	if (hostname.length == 0) {
		hostname = [RFSettings stringForKey:kAccountDefaultSite];
	}
	if (![RFSettings boolForKey:kHasSnippetsBlog] || hostname.length == 0) {
		return;
	}
	self.publishLabel.stringValue = [NSString stringWithFormat:@"Publish calendar as a page on %@?", hostname];
	self.publishLabel.toolTip = self.publishLabel.stringValue;
	self.publishButton.enabled = YES;
	[self fetchCalendarPagesAtOffset:0 generation:self.pageCheckGeneration];
}

- (void) fetchCalendarPagesAtOffset:(NSInteger)offset generation:(NSUInteger)generation
{
	NSDictionary* args = @{
		@"q": @"source",
		@"mp-channel": @"pages",
		@"mp-destination": self.pageDestinationUID,
		@"limit": @100,
		@"offset": @(offset)
	};
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	__weak MBCalendarController* weak_self = self;
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			MBCalendarController* controller = weak_self;
			if (!controller || generation != controller.pageCheckGeneration || ![controller pageDestinationIsCurrent]) {
				return;
			}
			NSNumber* contains_calendar = [[controller class] responseContainsCalendarPage:response.parsedResponse];
			if (response.httpError || response.httpResponse.statusCode != 200 || contains_calendar == nil || contains_calendar.boolValue) {
				return;
			}
			NSArray* items = response.parsedResponse[@"items"];
			if (items.count == 100) {
				[controller fetchCalendarPagesAtOffset:offset + items.count generation:generation];
			}
			else {
				[controller setPublishHeaderVisible:YES animated:NO];
			}
		});
	}];
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self checkCalendarPage];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	if (notification.object != self) {
		[self checkCalendarPage];
	}
}

- (void) addCalendarPage:(id)sender
{
	if (self.publishingPage || !self.publishButton.enabled || self.publishHeaderHeightConstraint.constant == 0) {
		return;
	}
	if (![self pageDestinationIsCurrent]) {
		[self checkCalendarPage];
		return;
	}
	self.pageCheckGeneration++;
	self.publishingPage = YES;
	self.publishButton.enabled = NO;
	self.publishSpinner.hidden = NO;
	[self.publishSpinner startAnimation:nil];

	NSDictionary* args = @{
		@"name": @"Book calendar",
		@"content": @"{{< bookcalendar view=\"list\" >}}",
		@"mp-channel": @"pages",
		@"mp-destination": self.pageDestinationUID,
		@"mp-syndicate-to[]": @[ @"" ],
		@"post-status": @"published"
	};
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	__weak MBCalendarController* weak_self = self;
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			MBCalendarController* controller = weak_self;
			if (!controller) {
				return;
			}
			controller.publishingPage = NO;
			[controller.publishSpinner stopAnimation:nil];
			controller.publishSpinner.hidden = YES;
			if (![controller pageDestinationIsCurrent]) {
				[controller checkCalendarPage];
				return;
			}
			NSDictionary* result = [response.parsedResponse isKindOfClass:NSDictionary.class] ? response.parsedResponse : nil;
			NSInteger status = response.httpResponse.statusCode;
			if (!response.httpError && status >= 200 && status < 300 && !result[@"error"]) {
				[controller setPublishHeaderVisible:NO animated:YES];
				[[NSNotificationCenter defaultCenter] postNotificationName:kClosePostingNotification object:controller];
			}
			else {
				controller.publishButton.enabled = YES;
				NSString* message = [result[@"error_description"] isKindOfClass:NSString.class] ? result[@"error_description"] : [response.httpError mb_networkMessageWithResponse:response.httpResponse];
				[controller showPageCreationError:message ?: @"The calendar page could not be created. Please try again."];
			}
		});
	}];
}

- (void) showPageCreationError:(NSString *)message
{
	if (!self.view.window) {
		return;
	}
	NSAlert* alert = [[NSAlert alloc] init];
	alert.messageText = @"Error Adding Calendar Page";
	alert.informativeText = message;
	[alert addButtonWithTitle:@"OK"];
	[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
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
	[self checkCalendarPage];
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
	if ((event.modifierFlags & NSEventModifierFlagCommand) && [index_path isEqual:self.selectedBookIndexPath]) {
		index_path = nil;
	}
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
