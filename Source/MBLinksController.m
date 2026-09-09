#import "MBLinksController.h"
#import "MBLinksTableView.h"
#import "MBBookmarkLink.h"
#import "MBBookmarkLinkCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "NSString+Extras.h"

@interface MBLinksController() <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@property (strong, nonatomic) NSTableView* tableView;
@property (strong, nonatomic) NSTextField* messageLabel;
@property (strong, nonatomic) NSButton* retryButton;
@property (strong, nonatomic) NSArray* links;
@property (strong, nonatomic) NSCache* thumbnails;
@property (strong, nonatomic) NSURLSession* imageSession;
@property (strong, nonatomic) NSMutableSet* deletingIDs;
@property (assign, nonatomic) NSUInteger loadGeneration;
@property (assign, nonatomic, readwrite) BOOL loading;
@end

@implementation MBLinksController

- (void) loadView
{
	self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
	self.links = @[];
	self.deletingIDs = [NSMutableSet set];
	self.thumbnails = [[NSCache alloc] init];
	self.thumbnails.countLimit = 100;
	NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	configuration.HTTPCookieStorage = nil;
	configuration.HTTPShouldSetCookies = NO;
	configuration.timeoutIntervalForRequest = 30;
	self.imageSession = [NSURLSession sessionWithConfiguration:configuration];
	NSScrollView* scroll_view = [[NSScrollView alloc] initWithFrame:self.view.bounds];
	scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
	scroll_view.hasVerticalScroller = YES;
	scroll_view.borderType = NSNoBorder;
	self.tableView = [[MBLinksTableView alloc] initWithFrame:scroll_view.bounds];
	self.tableView.headerView = nil;
	self.tableView.rowHeight = 152;
	self.tableView.intercellSpacing = NSMakeSize(0, 0);
	self.tableView.style = NSTableViewStyleFullWidth;
	self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.target = self;
	self.tableView.doubleAction = @selector(openSelectedLink:);
	NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"Link"];
	column.width = 500;
	[self.tableView addTableColumn:column];
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Link"];
	menu.delegate = self;
	menu.autoenablesItems = NO;
	self.tableView.menu = menu;
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

- (void) focusContent
{
	[self.view.window makeFirstResponder:self.tableView];
}

- (void) setLoading:(BOOL)loading
{
	_loading = loading;
	if (self.loadingDidChange) {
		self.loadingDidChange();
	}
}

- (void) reloadLinks
{
	[self view];
	NSUInteger generation = ++self.loadGeneration;
	self.messageLabel.hidden = YES;
	self.retryButton.hidden = YES;
	self.loading = YES;
	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/bookmarks/links"];
	[client getWithCompletion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			if (generation != self.loadGeneration) {
				return;
			}
			self.loading = NO;
			NSDictionary* feed = [response.parsedResponse isKindOfClass:[NSDictionary class]] ? response.parsedResponse : nil;
			if (response.httpError || response.httpResponse.statusCode != 200 || ![feed[@"items"] isKindOfClass:[NSArray class]]) {
				self.messageLabel.stringValue = @"Could not load saved links. Please try again.";
				self.messageLabel.hidden = NO;
				self.retryButton.hidden = NO;
				return;
			}
			NSMutableArray* links = [NSMutableArray array];
			for (id dictionary in feed[@"items"]) {
				if ([dictionary isKindOfClass:[NSDictionary class]]) {
					MBBookmarkLink* link = [[MBBookmarkLink alloc] initWithDictionary:dictionary];
					if (link.url && link.linkID.length) {
						[links addObject:link];
					}
				}
			}
			self.links = links;
			[self.tableView reloadData];
			self.messageLabel.stringValue = @"No saved links yet.";
			self.messageLabel.hidden = (links.count > 0);
		});
	}];
}

- (void) retryLoading:(id)sender
{
	[self reloadLinks];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.links.count;
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	MBBookmarkLinkCell* cell = [tableView makeViewWithIdentifier:@"Link" owner:self];
	if (cell == nil) {
		cell = [[MBBookmarkLinkCell alloc] initWithFrame:NSZeroRect];
		cell.identifier = @"Link";
	}
	MBBookmarkLink* link = self.links[row];
	[cell configureWithLink:link];
	if (link.thumbnailURL) {
		NSString* key = link.thumbnailURL.absoluteString;
		NSImage* cached = [self.thumbnails objectForKey:key];
		if (cached) {
			cell.thumbnailView.image = cached;
		}
		else {
			__weak MBLinksController* weak_self = self;
			__weak MBBookmarkLinkCell* weak_cell = cell;
			[[self.imageSession dataTaskWithURL:link.thumbnailURL completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
				NSImage* image = (!error && [(NSHTTPURLResponse *)response statusCode] == 200) ? [[NSImage alloc] initWithData:data] : nil;
				RFDispatchMainAsync(^{
					if (image.isValid) {
						[weak_self.thumbnails setObject:image forKey:key];
						if (weak_cell.link == link) {
							weak_cell.thumbnailView.image = image;
						}
					}
				});
			}] resume];
		}
	}
	return cell;
}

- (void) menuNeedsUpdate:(NSMenu *)menu
{
	[menu removeAllItems];
	NSInteger row = self.tableView.clickedRow;
	if (row < 0 || row >= self.links.count) {
		return;
	}
	MBBookmarkLink* link = self.links[row];
	NSArray* titles = @[[NSString mb_openInBrowserString], @"Copy Link", @"Delete"];
	NSArray* actions = @[@"openLink:", @"copyLink:", @"deleteLink:"];
	for (NSUInteger i = 0; i < titles.count; i++) {
		if (i == 2) {
			[menu addItem:[NSMenuItem separatorItem]];
		}
		NSMenuItem* item = [menu addItemWithTitle:titles[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""];
		item.target = self;
		item.representedObject = link;
		item.enabled = ![self.deletingIDs containsObject:link.linkID];
	}
}

- (void) openSelectedLink:(id)sender
{
	NSInteger row = sender == self.tableView ? self.tableView.clickedRow : self.tableView.selectedRow;
	if (row >= 0 && row < self.links.count) {
		MBBookmarkLink* link = self.links[row];
		[[NSWorkspace sharedWorkspace] openURL:link.url];
	}
}

- (void) keyDown:(NSEvent *)event
{
	if ([event.characters isEqualToString:@"\r"]) {
		[self openSelectedLink:nil];
	}
	else {
		[super keyDown:event];
	}
}

- (void) openLink:(NSMenuItem *)sender
{
	MBBookmarkLink* link = sender.representedObject;
	[[NSWorkspace sharedWorkspace] openURL:link.url];
}

- (void) copyLink:(NSMenuItem *)sender
{
	MBBookmarkLink* link = sender.representedObject;
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:link.url.absoluteString forType:NSPasteboardTypeString];
}

- (void) deleteLink:(NSMenuItem *)sender
{
	MBBookmarkLink* link = sender.representedObject;
	NSAlert* alert = [[NSAlert alloc] init];
	alert.messageText = @"Delete Saved Link?";
	alert.informativeText = link.title.length ? link.title : link.url.absoluteString;
	[alert addButtonWithTitle:@"Delete"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
		if (result != NSAlertFirstButtonReturn) {
			return;
		}
		[self.deletingIDs addObject:link.linkID];
		NSString* identifier = [link.linkID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
		// This is the same authenticated endpoint used by the web Links view.
		RFClient* client = [[RFClient alloc] initWithFormat:@"/bookmarks/links/%@", identifier];
		[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync(^{
				[self.deletingIDs removeObject:link.linkID];
				NSInteger status = response.httpResponse.statusCode;
				if (response.httpError || status < 200 || status >= 300 || ![response.parsedResponse isKindOfClass:[NSDictionary class]]) {
					NSAlert* error_alert = [[NSAlert alloc] init];
					error_alert.messageText = @"Could Not Delete Link";
					error_alert.informativeText = @"Please try again. The link has not been removed from this list.";
					if (self.view.window) {
						[error_alert beginSheetModalForWindow:self.view.window completionHandler:nil];
					}
					return;
				}
				[self reloadLinks];
			});
		}];
	}];
}

- (void) dealloc
{
	[self.imageSession invalidateAndCancel];
}

@end
