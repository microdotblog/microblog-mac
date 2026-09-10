#import "MBReaderController.h"
#import "RFConstants.h"
#import <WebKit/WebKit.h>

static NSMutableDictionary* gReaderControllers;

@interface MBReaderController() <NSWindowDelegate, WebFrameLoadDelegate, WebPolicyDelegate>
@property (copy, nonatomic) NSString* bookmarkID;
@property (strong, nonatomic) WebView* webView;
@end

@implementation MBReaderController

+ (NSString *) bookmarkIDForURL:(NSURL *)url
{
	NSString* scheme = url.scheme.lowercaseString;
	if (!([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) || ![url.host.lowercaseString isEqualToString:@"micro.blog"]) {
		return nil;
	}
	NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"^/bookmarks/([0-9]+)/?$" options:0 error:nil];
	NSString* path = url.path ?: @"";
	NSTextCheckingResult* match = [expression firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
	return match ? [path substringWithRange:[match rangeAtIndex:1]] : nil;
}

+ (void) showReaderWithBookmarkID:(NSString *)bookmarkID
{
	if (gReaderControllers == nil) {
		gReaderControllers = [NSMutableDictionary dictionary];
	}
	MBReaderController* controller = gReaderControllers[bookmarkID];
	if (controller == nil) {
		controller = [[self alloc] initWithBookmarkID:bookmarkID];
		gReaderControllers[bookmarkID] = controller;
	}
	[controller showWindow:nil];
	if (controller.window.miniaturized) {
		[controller.window deminiaturize:nil];
	}
	[controller.window makeKeyAndOrderFront:nil];
}

- (id) initWithBookmarkID:(NSString *)bookmarkID
{
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
	NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 800) styleMask:style backing:NSBackingStoreBuffered defer:NO];
	self = [super initWithWindow:window];
	if (self) {
		self.bookmarkID = bookmarkID;
		self.shouldCascadeWindows = NO;
		[self setupWindow];
		[self loadReader];
	}
	return self;
}

- (void) setupWindow
{
	NSWindow* window = self.window;
	window.title = @"Reader";
	window.contentMinSize = NSMakeSize(320, 300);
	window.releasedWhenClosed = NO;
	window.delegate = self;
	[window center];
	// AppKit requires a distinct autosave name for each simultaneously open window.
	NSString* autosave_name = [NSString stringWithFormat:@"Reader-%@", self.bookmarkID];
	[window setFrameUsingName:autosave_name];
	self.windowFrameAutosaveName = autosave_name;

	self.webView = [[WebView alloc] initWithFrame:window.contentView.bounds];
	self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	self.webView.frameLoadDelegate = self;
	self.webView.policyDelegate = self;
	[window.contentView addSubview:self.webView];
	window.initialFirstResponder = self.webView;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountDidChange:) name:kSignOutNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountDidChange:) name:kSwitchAccountNotification object:nil];
}

- (void) loadReader
{
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://micro.blog/hybrid/bookmarks/%@", self.bookmarkID]];
	[[self.webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.webView stopLoading:nil];
	self.webView.frameLoadDelegate = nil;
	self.webView.policyDelegate = nil;
	[self.webView close];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (gReaderControllers[self.bookmarkID] == self) {
		[gReaderControllers removeObjectForKey:self.bookmarkID];
	}
}

- (void) accountDidChange:(NSNotification *)notification
{
	[self close];
}

- (void) webView:(WebView *)webView didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	if (frame == webView.mainFrame && title.length > 0) {
		self.window.title = title;
	}
}

- (void) webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if ([actionInformation[WebActionNavigationTypeKey] integerValue] == WebNavigationTypeLinkClicked) {
		// Keep in-page anchors in the reader; open other destinations in the browser.
		NSURLComponents* destination = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:YES];
		NSURLComponents* current = [NSURLComponents componentsWithURL:webView.mainFrame.dataSource.request.URL resolvingAgainstBaseURL:YES];
		destination.fragment = nil;
		current.fragment = nil;
		if ([destination.URL isEqual:current.URL]) {
			[listener use];
			return;
		}
		[[NSWorkspace sharedWorkspace] openURL:request.URL];
		[listener ignore];
	}
	else {
		[listener use];
	}
}

- (void) webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[[NSWorkspace sharedWorkspace] openURL:request.URL];
	[listener ignore];
}

- (void) showLoadError:(NSError *)error forFrame:(WebFrame *)frame
{
	BOOL cancelled = [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled;
	BOOL interrupted = [error.domain isEqualToString:WebKitErrorDomain] && error.code == WebKitErrorFrameLoadInterruptedByPolicyChange;
	if (frame != self.webView.mainFrame || cancelled || interrupted) {
		return;
	}
	NSAlert* alert = [[NSAlert alloc] init];
	alert.messageText = @"Could Not Load Reader";
	alert.informativeText = error.localizedDescription;
	[alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void) webView:(WebView *)webView didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self showLoadError:error forFrame:frame];
}

- (void) webView:(WebView *)webView didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self showLoadError:error forFrame:frame];
}

@end
