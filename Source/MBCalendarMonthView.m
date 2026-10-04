#import "MBCalendarMonthView.h"
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

@implementation MBCalendarMonthView

- (instancetype) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		_selectedBookIndex = NSNotFound;
	}
	return self;
}

- (void) setSelectedBookIndex:(NSInteger)selectedBookIndex
{
	_selectedBookIndex = selectedBookIndex;
	self.needsDisplay = YES;
}

- (NSInteger) bookIndexAtPoint:(NSPoint)point
{
	if (point.x < 16 || point.x >= NSWidth(self.bounds) - 16 || point.y < 116) {
		return NSNotFound;
	}
	NSInteger index = (NSInteger)((point.y - 116) / 144);
	return index < [self.month[@"books"] count] ? index : NSNotFound;
}

- (void) setMonth:(NSDictionary *)month
{
	_month = month;
	NSMutableArray* descriptions = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld", CalendarMonthName(month, NO), (long)CalendarNumber(month[@"year"])]];
	for (NSDictionary* book in month[@"books"]) {
		[descriptions addObject:[NSString stringWithFormat:@"%@, %@, %@", CalendarString(book[@"title"]), CalendarString(book[@"author"]), CalendarBookDetails(book)]];
	}
	self.accessibilityElement = YES;
	self.accessibilityRole = NSAccessibilityGroupRole;
	self.accessibilityLabel = [descriptions componentsJoinedByString:@". "];
	self.needsDisplay = YES;
}

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

- (void) drawImage:(NSImage *)image inRect:(NSRect)rect fill:(BOOL)shouldFill dimmed:(BOOL)dimmed
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
	[NSGraphicsContext saveGraphicsState];
	if (!shouldFill) {
		// Round the fitted cover itself, not its larger layout box.
		[[NSBezierPath bezierPathWithRoundedRect:rect xRadius:4 yRadius:4] addClip];
	}
	[image drawInRect:rect fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
	if (dimmed) {
		[[NSColor colorWithWhite:0 alpha:0.18] setFill];
		NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
	}
	[NSGraphicsContext restoreGraphicsState];
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
	[self drawImage:self.imageForURL(CalendarString(self.month[@"background_url"])) inRect:header fill:YES dimmed:NO];
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
		BOOL selected = self.selectedBookIndex == i;
		if (selected) {
			BOOL dark_mode = [[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]] isEqualToString:NSAppearanceNameDarkAqua];
			[[NSColor colorWithWhite:dark_mode ? 0.18 : 0.96 alpha:1] setFill];
			NSRectFill(NSMakeRect(card.origin.x, top, card.size.width, 144));
		}
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
		[self drawImage:self.imageForURL(CalendarString(book[@"cover_url"])) inRect:cover_rect fill:NO dimmed:selected];
		NSString* title = CalendarString(book[@"title"]);
		[self drawText:title inRect:NSMakeRect(text_left, top + 36, text_width, 36) font:[NSFont boldSystemFontOfSize:16] color:NSColor.labelColor alignment:NSTextAlignmentLeft];
		[self drawText:CalendarString(book[@"author"]) inRect:NSMakeRect(text_left, top + 76, text_width, 18) font:[NSFont systemFontOfSize:13] color:NSColor.secondaryLabelColor alignment:NSTextAlignmentLeft];
		[self drawText:CalendarBookDetails(book) inRect:NSMakeRect(text_left, top + 96, text_width, 18) font:[NSFont systemFontOfSize:12] color:NSColor.secondaryLabelColor alignment:NSTextAlignmentLeft];
	}
	[NSGraphicsContext restoreGraphicsState];
	[[NSColor separatorColor] setStroke];
	outline.lineWidth = 0.5;
	[outline stroke];
}

@end
