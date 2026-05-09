//
//  RFBlogsController.m
//  Snippets
//
//  Created by Manton Reece on 3/21/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFBlogsController.h"

#import "RFBlogCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "RFAccount.h"

static NSString* const RFDestinationsCacheFilename = @"Destinations.json";
static CGFloat const RFHostnameButtonChevronSize = 12.0;
static CGFloat const RFHostnameFieldChevronSize = 12.0;
static CGFloat const RFHostnameChevronSpacing = 6.0;

@interface RFHostnameButton ()

@property (strong, nonatomic) NSImageView* chevronView;
@property (strong, nonatomic) NSTrackingArea* trackingArea;
@property (assign, nonatomic) BOOL isHovering;

- (void) setupChevron;
- (void) updateChevronFrame;
- (void) updateChevronVisibility;

@end

@implementation RFHostnameButton

- (void) awakeFromNib
{
	[super awakeFromNib];
	[self setupChevron];
}

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupChevron];
	}
	return self;
}

- (void) setupChevron
{
	if (self.chevronView != nil) {
		return;
	}

	NSImage* chevron_image = [NSImage imageWithSystemSymbolName:@"chevron.down" accessibilityDescription:@"Show Blogs"];
	self.chevronView = [[NSImageView alloc] initWithFrame:NSZeroRect];
	self.chevronView.image = chevron_image;
	self.chevronView.imageScaling = NSImageScaleProportionallyDown;
	self.chevronView.hidden = YES;
	[self addSubview:self.chevronView];
}

- (void) layout
{
	[super layout];
	[self updateChevronFrame];
}

- (void) setTitle:(NSString *)title
{
	[super setTitle:title];
	[self invalidateIntrinsicContentSize];
	[self updateChevronFrame];
}

- (NSSize) intrinsicContentSize
{
	NSSize size = [super intrinsicContentSize];

	if (self.showsChevron) {
		size.width += RFHostnameChevronSpacing + RFHostnameButtonChevronSize;
	}

	return size;
}

- (void) updateChevronFrame
{
	NSFont* font = self.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]];
	CGFloat text_width = ceil([self.title ?: @"" sizeWithAttributes:@{ NSFontAttributeName: font }].width);
	NSRect title_rect = [self.cell titleRectForBounds:self.bounds];
	CGFloat x = NSMinX(title_rect) + text_width + RFHostnameChevronSpacing;
	x = MIN(x, NSMaxX(self.bounds) - RFHostnameButtonChevronSize);
	CGFloat y = floor(NSMidY(self.bounds) - (RFHostnameButtonChevronSize / 2.0));
	self.chevronView.frame = NSMakeRect(x, y, RFHostnameButtonChevronSize, RFHostnameButtonChevronSize);
}

- (void) updateTrackingAreas
{
	[super updateTrackingAreas];

	if (self.trackingArea != nil) {
		[self removeTrackingArea:self.trackingArea];
	}

	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;
	self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
	[self addTrackingArea:self.trackingArea];
}

- (void) mouseEntered:(NSEvent *)event
{
	self.isHovering = YES;
	[self updateChevronVisibility];
}

- (void) mouseExited:(NSEvent *)event
{
	self.isHovering = NO;
	[self updateChevronVisibility];
}

- (void) mouseDown:(NSEvent *)event
{
	if (!self.enabled) {
		[super mouseDown:event];
		return;
	}

	[self highlight:YES];
	[NSApp sendAction:self.action to:self.target from:self];
	[self highlight:NO];
}

- (void) setShowsChevron:(BOOL)showsChevron
{
	_showsChevron = showsChevron;
	[self invalidateIntrinsicContentSize];
	[self updateChevronVisibility];
}

- (void) updateChevronVisibility
{
	[self updateChevronFrame];
	self.chevronView.hidden = !(self.showsChevron && self.isHovering);
}

@end

@interface RFHostnameField ()

@property (strong, nonatomic) NSImageView* chevronView;
@property (strong, nonatomic) NSTrackingArea* trackingArea;
@property (assign, nonatomic) BOOL isHovering;
@property (copy, nonatomic) NSString* displayString;

- (void) setupChevron;
- (void) updateChevronVisibility;

@end

@implementation RFHostnameField

@synthesize showsChevron = _showsChevron;

- (void) awakeFromNib
{
	[super awakeFromNib];
	[self setupChevron];
}

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupChevron];
	}
	return self;
}

- (void) setupChevron
{
	if (self.chevronView != nil) {
		return;
	}

	NSImage* chevron_image = [NSImage imageWithSystemSymbolName:@"chevron.down" accessibilityDescription:@"Show Blogs"];
	self.chevronView = [[NSImageView alloc] initWithFrame:NSZeroRect];
	self.chevronView.image = chevron_image;
	self.chevronView.imageScaling = NSImageScaleProportionallyDown;
	self.chevronView.hidden = YES;
	[self addSubview:self.chevronView];
	self.textColor = [NSColor secondaryLabelColor];
	self.displayString = self.stringValue ?: @"";
}

- (void) layout
{
	[super layout];
	[self updateChevronFrame];
}

- (void) setStringValue:(NSString *)stringValue
{
	self.displayString = stringValue ?: @"";
	[super setStringValue:self.displayString];
	[self updateChevronVisibility];
}

- (void) updateChevronFrame
{
	CGFloat size = RFHostnameFieldChevronSize;
	CGFloat spacing = RFHostnameChevronSpacing;
	NSRect hostname_rect = [self hostnameRect];
	CGFloat text_x = NSMinX(hostname_rect);
	CGFloat text_width = NSWidth(hostname_rect);
	CGFloat x = text_x + text_width + spacing;
	CGFloat y = floor(NSMidY(self.bounds) - (size / 2.0));
	self.chevronView.frame = NSMakeRect(x, y, size, size);
}

- (NSRect) hostnameRect
{
	NSFont* font = self.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]];
	CGFloat text_width = ceil([self.displayString ?: @"" sizeWithAttributes:@{ NSFontAttributeName: font }].width);
	CGFloat text_x = 0.0;

	if (self.alignment == NSTextAlignmentCenter) {
		text_x = floor((NSWidth(self.bounds) - text_width) / 2.0);
	}
	else if (self.alignment == NSTextAlignmentRight) {
		text_x = NSWidth(self.bounds) - text_width;
	}

	return NSMakeRect(text_x, 0.0, text_width, NSHeight(self.bounds));
}

- (void) updateTrackingAreas
{
	[super updateTrackingAreas];

	if (self.trackingArea != nil) {
		[self removeTrackingArea:self.trackingArea];
	}

	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;
	self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
	[self addTrackingArea:self.trackingArea];
}

- (void) mouseEntered:(NSEvent *)event
{
	self.isHovering = YES;
	[self updateChevronVisibility];
}

- (void) mouseExited:(NSEvent *)event
{
	self.isHovering = NO;
	[self updateChevronVisibility];
}

- (void) mouseDown:(NSEvent *)event
{
	if (self.mouseDownHandler != nil) {
		self.mouseDownHandler(self, event);
		return;
	}

	[super mouseDown:event];
}

- (void) setShowsChevron:(BOOL)showsChevron
{
	_showsChevron = showsChevron;
	[self updateChevronVisibility];
}

- (void) updateChevronVisibility
{
	[self updateChevronFrame];
	self.chevronView.hidden = !(self.showsChevron && self.isHovering);
}

@end

@implementation RFBlogsController

+ (NSString *) destinationsCacheFile
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];
	if (support_folder.length == 0) {
		return nil;
	}

	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	NSString* caches_folder = [microblog_folder stringByAppendingPathComponent:@"Caches"];
	[[NSFileManager defaultManager] createDirectoryAtPath:caches_folder withIntermediateDirectories:YES attributes:nil error:NULL];
	return [caches_folder stringByAppendingPathComponent:RFDestinationsCacheFilename];
}

+ (NSArray *) normalizedDestinationsFromDestinations:(NSArray *)destinations
{
	NSMutableArray* normalized_destinations = [NSMutableArray array];
	for (id object in destinations) {
		if (![object isKindOfClass:[NSDictionary class]]) {
			continue;
		}

		NSDictionary* d = (NSDictionary*) object;
		NSString* uid = d[@"uid"] ?: @"";
		NSString* name = d[@"name"] ?: @"";
		if (uid.length == 0 || name.length == 0) {
			continue;
		}

		NSMutableDictionary* destination = [NSMutableDictionary dictionaryWithDictionary:@{
			@"uid": uid,
			@"name": name
		}];

		for (NSString* key in d) {
			id value = d[key];
			if ([key isKindOfClass:[NSString class]] && [NSJSONSerialization isValidJSONObject:@[ value ]]) {
				destination[key] = value;
			}
		}

		[normalized_destinations addObject:destination];
	}

	return normalized_destinations;
}

+ (NSArray *) cachedDestinations
{
	NSString* cache_file = [self destinationsCacheFile];
	NSData* data = [NSData dataWithContentsOfFile:cache_file];
	if (data.length > 0) {
		id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if ([payload isKindOfClass:[NSArray class]]) {
			return [self normalizedDestinationsFromDestinations:payload];
		}
	}

	NSString* username = [RFSettings defaultAccount].username;
	NSString* pref_key = [NSString stringWithFormat:@"%@_%@", username, @"Destinations"];
	NSArray* old_cached = [[NSUserDefaults standardUserDefaults] arrayForKey:pref_key];
	if (old_cached.count > 0) {
		return [self normalizedDestinationsFromDestinations:old_cached];
	}

	return @[];
}

+ (void) saveCachedDestinationsFrom:(NSArray *)destinations
{
	NSArray* normalized_destinations = [self normalizedDestinationsFromDestinations:destinations];
	NSString* cache_file = [self destinationsCacheFile];
	NSData* data = [NSJSONSerialization dataWithJSONObject:normalized_destinations options:0 error:nil];
	if (data.length > 0) {
		[data writeToFile:cache_file atomically:YES];
	}
}

+ (void) clearCachedDestinations
{
	NSString* cache_file = [self destinationsCacheFile];
	if (cache_file.length > 0) {
		BOOL is_directory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:cache_file isDirectory:&is_directory] && !is_directory) {
			[[NSFileManager defaultManager] removeItemAtPath:cache_file error:nil];
		}
	}

	for (RFAccount* account in [RFSettings accounts]) {
		if (account.username.length > 0) {
			NSString* pref_key = [NSString stringWithFormat:@"%@_%@", account.username, @"Destinations"];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:pref_key];
		}
	}
}

+ (void) fetchDestinationsInBackgroundWithCompletion:(void (^)(NSArray* destinations))completion
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
		NSArray* destinations = nil;
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			destinations = [response.parsedResponse objectForKey:@"destination"];
			[self saveCachedDestinationsFrom:destinations];
		}

		NSArray* cached_destinations = [self cachedDestinations];
		if (completion != nil) {
			RFDispatchMainAsync(^{
				completion(cached_destinations);
			});
		}
	}];
}

+ (BOOL) hasMultipleCachedDestinations
{
	return ([self cachedDestinations].count > 1);
}

+ (NSMenu *) blogsMenuWithTarget:(id)target action:(SEL)action
{
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Blogs"];
	NSString* current_uid = [RFSettings stringForKey:kCurrentDestinationUID] ?: @"";

	for (NSDictionary* destination in [self cachedDestinations]) {
		NSString* name = destination[@"name"];
		if (name.length == 0) {
			continue;
		}

		NSMenuItem* menu_item = [[NSMenuItem alloc] initWithTitle:name action:action keyEquivalent:@""];
		menu_item.target = target;
		menu_item.representedObject = destination;
		if (current_uid.length > 0 && [current_uid isEqualToString:(destination[@"uid"] ?: @"")]) {
			menu_item.state = NSControlStateValueOn;
		}
		[menu addItem:menu_item];
	}

#if 0
	if (menu.numberOfItems > 0) {
		[menu addItem:[NSMenuItem separatorItem]];
	}

	NSMenuItem* new_blog_item = [[NSMenuItem alloc] initWithTitle:@"New Blog..." action:action keyEquivalent:@""];
	new_blog_item.target = target;
	[menu addItem:new_blog_item];
#endif

	return menu;
}

+ (void) selectDestinationMenuItem:(NSMenuItem *)menuItem
{
	NSDictionary* destination = menuItem.representedObject;
	if ([destination isKindOfClass:[NSDictionary class]]) {
		[RFSettings setString:destination[@"uid"] forKey:kCurrentDestinationUID];
		[RFSettings setString:destination[@"name"] forKey:kCurrentDestinationName];
		[[NSNotificationCenter defaultCenter] postNotificationName:kUpdatedBlogNotification object:self];
	}
	else {
		NSURL* url = [NSURL URLWithString:@"https://micro.blog/new/site"];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (instancetype) init
{
	self = [super initWithNibName:@"Blogs" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];

	// try cached destinations first, refresh in background
	NSArray* cached = [self loadCachedDestinations];
	if (cached.count > 0) {
		self.destinations = cached;
		[self.tableView reloadData];
		[self fetchBlogsShowProgress:NO];
	}
	else {
		[self fetchBlogsShowProgress:YES];
	}
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BlogCell" bundle:nil] forIdentifier:@"BlogCell"];
}

- (NSString *) cachedDestinationsPrefKey
{
	NSString* username = [RFSettings defaultAccount].username;
	return [NSString stringWithFormat:@"%@_%@", username, @"Destinations"];
}

- (NSArray *) loadCachedDestinations
{
	return [[self class] cachedDestinations];
}

- (void) saveCachedDestinationsFrom:(NSArray *)destinations
{
	[[self class] saveCachedDestinationsFrom:destinations];
}

- (void) fetchBlogsShowProgress:(BOOL)showProgress
{
	if (showProgress) {
		self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer* timer) {
			// only show progress if download is taking longer than 1 second
			[self.progressSpinner startAnimation:nil];
		}];
	}
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:@{ @"q": @"config" } completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* destinations = [response.parsedResponse objectForKey:@"destination"];
			[self saveCachedDestinationsFrom:destinations];
			self.destinations = [self loadCachedDestinations];
			RFDispatchMainAsync (^{
				[self.progressTimer invalidate];
				[self.progressSpinner stopAnimation:nil];
				[self.tableView reloadData];
			});
		}
	}];
}

- (void) fetchBlogs
{
	[self fetchBlogsShowProgress:YES];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.destinations.count + 1;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFBlogCell* cell = [tableView makeViewWithIdentifier:@"BlogCell" owner:self];

	if (row < self.destinations.count) {
		NSDictionary* destination = [self.destinations objectAtIndex:row];
		cell.nameField.stringValue = destination[@"name"];
	}
	else {
		cell.nameField.stringValue = @"New Blog...";
	}

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	if (row < self.destinations.count) {
		NSDictionary* destination = [self.destinations objectAtIndex:row];

		[RFSettings setString:destination[@"uid"] forKey:kCurrentDestinationUID];
		[RFSettings setString:destination[@"name"] forKey:kCurrentDestinationName];

		[[NSNotificationCenter defaultCenter] postNotificationName:kUpdatedBlogNotification object:self];
	}
	else {
		NSURL* url = [NSURL URLWithString:@"https://micro.blog/new/site"];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
	
	return YES;
}

@end
