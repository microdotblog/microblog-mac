#import "MBBookSearchDetailsController.h"
#import "MBBook.h"
#import "NSColor+Extras.h"
#import "RFMacros.h"

@interface MBBookSearchArtworkView : NSView

@property (strong, nonatomic) NSImage* image;
@property (strong, nonatomic) NSColor* backgroundColor;
@property (assign, nonatomic) BOOL background;

@end

@implementation MBBookSearchArtworkView

- (void) setImage:(NSImage *)image
{
	_image = image;
	self.needsDisplay = YES;
}

- (void) setBackgroundColor:(NSColor *)color
{
	_backgroundColor = color;
	self.needsDisplay = YES;
}

- (void) drawRect:(NSRect)dirtyRect
{
	NSSize size = self.image.size;
	BOOL has_image = self.image.isValid && size.width > 0 && size.height > 0;
	if (self.background) {
		[[NSColor textBackgroundColor] setFill];
		NSRectFill(self.bounds);
		// Tint the normal appearance with one background source, not both.
		if (!has_image && self.backgroundColor) {
			[[self.backgroundColor colorWithAlphaComponent:0.2] setFill];
			NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
		}
	}
	if (!has_image || NSIsEmptyRect(self.bounds)) {
		return;
	}

	NSRect source = NSMakeRect(0, 0, size.width, size.height);
	NSRect destination = self.bounds;
	if (self.background) {
		CGFloat scale = MAX(NSWidth(destination) / size.width, NSHeight(destination) / size.height);
		NSSize crop = NSMakeSize(NSWidth(destination) / scale, NSHeight(destination) / scale);
		source = NSMakeRect((size.width - crop.width) / 2, (size.height - crop.height) / 2, crop.width, crop.height);
	}
	else {
		CGFloat scale = MIN(NSWidth(destination) / size.width, NSHeight(destination) / size.height);
		NSSize fitted_size = NSMakeSize(size.width * scale, size.height * scale);
		destination = NSMakeRect(NSMidX(destination) - fitted_size.width / 2, NSMidY(destination) - fitted_size.height / 2, fitted_size.width, fitted_size.height);
	}

	[NSGraphicsContext saveGraphicsState];
	if (!self.background) {
		[[NSBezierPath bezierPathWithRoundedRect:destination xRadius:5 yRadius:5] addClip];
	}
	[self.image drawInRect:destination fromRect:source operation:NSCompositingOperationSourceOver fraction:self.background ? 0.2 : 1.0 respectFlipped:YES hints:nil];
	[NSGraphicsContext restoreGraphicsState];
}

@end

@interface MBBookSearchDocumentView : NSView
@end

@implementation MBBookSearchDocumentView

- (BOOL) isFlipped
{
	return YES;
}

@end

@interface MBBookSearchDetailsController ()

@property (strong, nonatomic) NSScrollView* scrollView;
@property (strong, nonatomic) MBBookSearchArtworkView* headerView;
@property (strong, nonatomic) MBBookSearchArtworkView* coverView;
@property (strong, nonatomic) NSTextField* titleField;
@property (strong, nonatomic) NSTextField* authorField;
@property (strong, nonatomic) NSTextField* descriptionField;
@property (strong, nonatomic) NSURLSessionDataTask* backgroundTask;
@property (assign, nonatomic) NSUInteger backgroundRequestID;

@end

@implementation MBBookSearchDetailsController

- (void) dealloc
{
	[self.backgroundTask cancel];
}

- (void) loadView
{
	self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 500)];
	self.scrollView = [[NSScrollView alloc] initWithFrame:self.view.bounds];
	self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	self.scrollView.borderType = NSNoBorder;
	self.scrollView.hasVerticalScroller = YES;
	self.scrollView.autohidesScrollers = YES;
	self.scrollView.backgroundColor = [NSColor textBackgroundColor];
	[self.view addSubview:self.scrollView];

	NSView* document_view = [[MBBookSearchDocumentView alloc] initWithFrame:self.view.bounds];
	document_view.translatesAutoresizingMaskIntoConstraints = NO;
	self.scrollView.documentView = document_view;
	self.headerView = [[MBBookSearchArtworkView alloc] initWithFrame:NSZeroRect];
	self.headerView.background = YES;
	self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
	[document_view addSubview:self.headerView];

	self.coverView = [[MBBookSearchArtworkView alloc] initWithFrame:NSZeroRect];
	self.coverView.translatesAutoresizingMaskIntoConstraints = NO;
	self.coverView.accessibilityElement = YES;
	self.coverView.accessibilityRole = NSAccessibilityImageRole;
	[self.headerView addSubview:self.coverView];
	NSLayoutConstraint* cover_width = [self.coverView.widthAnchor constraintEqualToConstant:140];
	cover_width.priority = NSLayoutPriorityDefaultLow;

	NSBox* title_box = [[NSBox alloc] initWithFrame:NSZeroRect];
	title_box.translatesAutoresizingMaskIntoConstraints = NO;
	title_box.boxType = NSBoxCustom;
	title_box.borderWidth = 0;
	title_box.titlePosition = NSNoTitle;
	title_box.cornerRadius = 0;
	title_box.fillColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.8];
	title_box.contentViewMargins = NSZeroSize;
	[self.headerView addSubview:title_box];

	self.titleField = [NSTextField wrappingLabelWithString:@""];
	self.titleField.font = [NSFont boldSystemFontOfSize:18];
	self.titleField.alignment = NSTextAlignmentCenter;
	self.authorField = [NSTextField wrappingLabelWithString:@""];
	self.authorField.font = [NSFont systemFontOfSize:13];
	self.authorField.alignment = NSTextAlignmentCenter;
	self.authorField.textColor = [NSColor secondaryLabelColor];
	NSStackView* title_stack = [NSStackView stackViewWithViews:@[self.titleField, self.authorField]];
	title_stack.translatesAutoresizingMaskIntoConstraints = NO;
	title_stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	title_stack.alignment = NSLayoutAttributeCenterX;
	title_stack.spacing = 6;
	[title_box.contentView addSubview:title_stack];

	self.descriptionField = [NSTextField wrappingLabelWithString:@""];
	self.descriptionField.translatesAutoresizingMaskIntoConstraints = NO;
	self.descriptionField.selectable = YES;
	// Preserve paragraph spacing in AppKit's field editor when selecting text.
	self.descriptionField.allowsEditingTextAttributes = YES;
	self.descriptionField.font = [NSFont systemFontOfSize:13];
	[document_view addSubview:self.descriptionField];

	[NSLayoutConstraint activateConstraints:@[
		[self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[document_view.leadingAnchor constraintEqualToAnchor:self.scrollView.contentView.leadingAnchor],
		[document_view.topAnchor constraintEqualToAnchor:self.scrollView.contentView.topAnchor],
		[document_view.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],
		[self.headerView.leadingAnchor constraintEqualToAnchor:document_view.leadingAnchor],
		[self.headerView.trailingAnchor constraintEqualToAnchor:document_view.trailingAnchor],
		[self.headerView.topAnchor constraintEqualToAnchor:document_view.topAnchor],
		[self.coverView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:20],
		[self.coverView.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
		[self.coverView.widthAnchor constraintLessThanOrEqualToAnchor:self.headerView.widthAnchor constant:-32],
		[self.coverView.heightAnchor constraintEqualToAnchor:self.coverView.widthAnchor multiplier:1.5],
		cover_width,
		[title_box.topAnchor constraintEqualToAnchor:self.coverView.bottomAnchor constant:20],
		[title_box.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
		[title_box.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
		[title_box.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
		[title_stack.leadingAnchor constraintEqualToAnchor:title_box.contentView.leadingAnchor constant:12],
		[title_stack.trailingAnchor constraintEqualToAnchor:title_box.contentView.trailingAnchor constant:-12],
		[title_stack.topAnchor constraintEqualToAnchor:title_box.contentView.topAnchor constant:12],
		[title_stack.bottomAnchor constraintEqualToAnchor:title_box.contentView.bottomAnchor constant:-12],
		[self.titleField.widthAnchor constraintEqualToAnchor:title_stack.widthAnchor],
		[self.authorField.widthAnchor constraintEqualToAnchor:title_stack.widthAnchor],
		[self.descriptionField.leadingAnchor constraintEqualToAnchor:document_view.leadingAnchor constant:16],
		[self.descriptionField.trailingAnchor constraintEqualToAnchor:document_view.trailingAnchor constant:-16],
		[self.descriptionField.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:20],
		[self.descriptionField.bottomAnchor constraintEqualToAnchor:document_view.bottomAnchor constant:-20]
	]];
}

- (void) setBook:(MBBook *)book
{
	_book = book;
	(void)self.view;
	self.scrollView.hidden = (book == nil);
	self.titleField.stringValue = book.title ?: @"";
	self.authorField.stringValue = book.authors.count ? [@"by " stringByAppendingString:[book.authors componentsJoinedByString:@", "]] : @"";
	self.authorField.hidden = (book.authors.count == 0);
	self.coverView.accessibilityLabel = book.title ?: @"Book cover";

	NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
	style.lineSpacing = 4;
	NSString* description = [book.bookDescription isKindOfClass:[NSString class]] ? book.bookDescription : @"";
	description = [description stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	self.descriptionField.attributedStringValue = [[NSAttributedString alloc] initWithString:description attributes:@{
		NSFontAttributeName: [NSFont systemFontOfSize:13],
		NSForegroundColorAttributeName: [NSColor labelColor],
		NSParagraphStyleAttributeName: style
	}];
	[self updateCover];
	[self updateBackground];
	[self.view layoutSubtreeIfNeeded];
	[self.scrollView.contentView scrollToPoint:NSZeroPoint];
	[self.scrollView reflectScrolledClipView:self.scrollView.contentView];
}

- (void) updateCover
{
	NSImage* image = self.book.coverImage ?: [self.book cachedCover];
	self.coverView.image = image;
}

- (void) updateBackground
{
	[self.backgroundTask cancel];
	self.backgroundTask = nil;
	NSUInteger request_id = ++self.backgroundRequestID;
	MBBook* book = self.book;
	self.headerView.image = nil;
	self.headerView.backgroundColor = book.backgroundColor.length ? [NSColor mb_colorFromString:book.backgroundColor] : nil;

	NSURL* url = book.backgroundURL.length ? [NSURL URLWithString:book.backgroundURL] : nil;
	if (![@[@"https", @"http"] containsObject:url.scheme.lowercaseString] || url.host.length == 0) {
		return;
	}

	__weak MBBookSearchDetailsController* weak_self = self;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSString* cache_path = [book pathForCachedBackground];
		NSImage* cached_image = cache_path ? [[NSImage alloc] initWithContentsOfFile:cache_path] : nil;
		RFDispatchMainAsync(^{
			MBBookSearchDetailsController* controller = weak_self;
			if (!controller || request_id != controller.backgroundRequestID) {
				return;
			}
			if (cached_image.isValid) {
				controller.headerView.image = cached_image;
				return;
			}

			controller.backgroundTask = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
				NSImage* image = !error && [(NSHTTPURLResponse *)response statusCode] == 200 && data.length < 15 * 1024 * 1024 ? [[NSImage alloc] initWithData:data] : nil;
				if (image.isValid && cache_path) {
					[image.TIFFRepresentation writeToFile:cache_path atomically:YES];
				}
				RFDispatchMainAsync(^{
					MBBookSearchDetailsController* current_controller = weak_self;
					if (request_id == current_controller.backgroundRequestID) {
						current_controller.backgroundTask = nil;
						current_controller.headerView.image = image.isValid ? image : nil;
					}
				});
			}];
			[controller.backgroundTask resume];
		});
	});
}

@end
