#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "RFPhotoZoomController.h"
#import "MBVideoZoomController.h"
#import "RFConstants.h"

// Link with RFPhotoZoomController.m, MBVideoZoomController.m, Cocoa, and WebKit.
// Requests are intercepted in memory; the app and external network are not used.
@interface RFPhotoZoomController (ViewerTests)
@property (strong) NSScrollView* scrollView;
@property (strong) NSView* canvasView;
@property (strong) NSImageView* imageView;
@property (strong) NSButton* htmlCopyButton;
@property (strong) NSProgressIndicator* progressIndicator;
@property (strong) NSView* titlebarBackgroundView;
@property (strong) NSMagnificationGestureRecognizer* magnificationGestureRecognizer;
@property (strong) NSURLSessionDataTask* imageTask;
@property CGFloat zoomScale;
@property NSSize imageSize;
- (void) loadImageURL:(NSURL *)imageURL;
- (void) revealLoadedImage:(NSImage *)image;
- (void) updateImageLayout;
- (CGFloat) minimumZoomScaleForCurrentViewport;
- (NSPoint) currentImageRelativeCenterPoint;
- (void) scrollToKeepImageRelativeCenterPoint:(NSPoint)point;
- (void) handleMagnificationGesture:(NSMagnificationGestureRecognizer *)gesture;
- (void) zoomIn:(id)sender;
- (void) zoomOut:(id)sender;
- (BOOL) validateToolbarItem:(NSToolbarItem *)item;
- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
@end

@interface TestMagnificationGesture : NSMagnificationGestureRecognizer
@property NSGestureRecognizerState testState;
@end
@implementation TestMagnificationGesture
- (NSGestureRecognizerState) state { return self.testState; }
@end

@interface RFPhotoCanvasView : NSView
- (BOOL) shouldAllowDragScrolling;
@end
@interface TestPanWindow : NSWindow
@property (strong) NSMutableArray* events;
@end
@implementation TestPanWindow
- (NSEvent *) nextEventMatchingMask:(NSEventMask)mask
{
	NSEvent* event = self.events.firstObject;
	if (event != nil) { [self.events removeObjectAtIndex:0]; }
	return event;
}
@end

static NSMutableDictionary* pending_requests;
static NSInteger cancelled_requests;

@interface TestImageProtocol : NSURLProtocol
@end
@implementation TestImageProtocol
+ (BOOL) canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void) startLoading
{
	NSCAssert([self.request.URL.host isEqualToString:@"photo-viewer.test"], @"Never allow external network requests in this test");
	dispatch_async(dispatch_get_main_queue(), ^{ pending_requests[self.request.URL.path] = self; });
}
- (void) stopLoading
{
	dispatch_async(dispatch_get_main_queue(), ^{
		cancelled_requests++;
		if (pending_requests[self.request.URL.path] == self) {
			[pending_requests removeObjectForKey:self.request.URL.path];
		}
	});
}
@end

static NSPasteboard* test_pasteboard;
@interface NSPasteboard (ViewerTests)
+ (NSPasteboard *) viewerTestPasteboard;
@end
@implementation NSPasteboard (ViewerTests)
+ (NSPasteboard *) viewerTestPasteboard { return test_pasteboard; }
@end

static void spin_until(BOOL (^condition)(void))
{
	NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:5];
	while (!condition() && deadline.timeIntervalSinceNow > 0) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	NSCAssert(condition(), @"Timed out waiting for the viewer");
}

static void respond(NSString* path, NSInteger status, NSData* data)
{
	spin_until(^BOOL { return pending_requests[path] != nil; });
	TestImageProtocol* protocol = pending_requests[path];
	[pending_requests removeObjectForKey:path];
	NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:protocol.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Content-Type": @"image/png" }];
	[protocol.client URLProtocol:protocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[protocol.client URLProtocol:protocol didLoadData:data];
	[protocol.client URLProtocolDidFinishLoading:protocol];
}

static NSImage* fixture_image(void)
{
	NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1000)];
	[image lockFocus];
	[[NSColor colorWithSRGBRed:0.16 green:0.42 blue:0.72 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, 0, 1600, 1000));
	[[NSColor colorWithSRGBRed:0.95 green:0.76 blue:0.22 alpha:1] setFill];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1060, 610, 250, 250)] fill];
	[[NSColor colorWithSRGBRed:0.12 green:0.28 blue:0.24 alpha:1] setFill];
	NSBezierPath* mountain = [NSBezierPath bezierPath];
	[mountain moveToPoint:NSMakePoint(0, 0)];
	[mountain lineToPoint:NSMakePoint(680, 820)];
	[mountain lineToPoint:NSMakePoint(1350, 0)];
	[mountain closePath];
	[mountain fill];
	[image unlockFocus];
	return image;
}

static NSEvent* mouse_event(NSEventType type, NSPoint point, NSWindow* window)
{
	return [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
}

static NSToolbarItem* toolbar_item(RFPhotoZoomController* controller, NSString* identifier)
{
	for (NSToolbarItem* item in controller.window.toolbar.items) {
		if ([item.itemIdentifier isEqualToString:identifier]) { return item; }
	}
	NSCAssert(NO, @"The actual toolbar must contain %@", identifier);
	return nil;
}

static void test_panning(void)
{
	TestPanWindow* window = [[TestPanWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
	NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:window.contentView.bounds];
	RFPhotoCanvasView* canvas = [[RFPhotoCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 800)];
	scroll.documentView = canvas;
	[window.contentView addSubview:scroll];
	[scroll.contentView scrollToPoint:NSMakePoint(200, 200)];
	NSCAssert([canvas shouldAllowDragScrolling], @"An enlarged image can be dragged");
	window.events = [@[mouse_event(NSEventTypeLeftMouseDragged, NSMakePoint(50, 80), window), mouse_event(NSEventTypeLeftMouseUp, NSMakePoint(50, 80), window)] mutableCopy];
	[canvas mouseDown:mouse_event(NSEventTypeLeftMouseDown, NSMakePoint(100, 100), window)];
	NSCAssert(NSEqualPoints(scroll.contentView.bounds.origin, NSMakePoint(250, 220)), @"Drag movement pans the image in both axes");
	window.events = [@[mouse_event(NSEventTypeLeftMouseDragged, NSMakePoint(-5000, -5000), window), mouse_event(NSEventTypeLeftMouseUp, NSMakePoint(-5000, -5000), window)] mutableCopy];
	[canvas mouseDown:mouse_event(NSEventTypeLeftMouseDown, NSMakePoint(0, 0), window)];
	NSCAssert(NSMaxX(scroll.contentView.bounds) <= NSWidth(canvas.bounds) && NSMaxY(scroll.contentView.bounds) <= NSHeight(canvas.bounds), @"Panning stays inside image bounds");
	[window close];
}

static CGFloat validate_appearance(RFPhotoZoomController* controller, NSAppearanceName appearance)
{
	controller.window.appearance = [NSAppearance appearanceNamed:appearance];
	[controller.window orderFront:nil];
	[controller.window.contentView layoutSubtreeIfNeeded];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.35]];
	[NSApp updateWindows];
	[controller.window display];
	[controller.titlebarBackgroundView updateLayer];
	NSCAssert(controller.imageView.alphaValue == 1 && !NSIsEmptyRect(controller.imageView.visibleRect), @"The loaded photo must be visible in the scroll viewport");
	NSColor* background = [[NSColor colorWithCGColor:controller.titlebarBackgroundView.layer.backgroundColor] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	NSCAssert(fabs(background.alphaComponent - 0.8) < 0.001, @"Keep the titlebar background translucent in each appearance");
	NSBitmapImageRep* image_bitmap = [controller.imageView bitmapImageRepForCachingDisplayInRect:controller.imageView.bounds];
	[controller.imageView cacheDisplayInRect:controller.imageView.bounds toBitmapImageRep:image_bitmap];
	NSColor* pixel = [[image_bitmap colorAtX:5 y:5] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
	NSCAssert(pixel.alphaComponent > 0.9 && pixel.blueComponent > pixel.redComponent + 0.2, @"The view actually paints the fixture photo rather than a blank canvas");
	return background.redComponent;
}

int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		pending_requests = [NSMutableDictionary dictionary];
		[NSURLProtocol registerClass:[TestImageProtocol class]];
		NSString* original_url = @"https://photo-viewer.test/images/600/picture.png?size=600";
		NSString* encoded = [original_url stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
		for (NSString* prefix in @[@"https://micro.blog/photos/600/", @"https://cdn.micro.blog/photos/800/"]) {
			NSURL* proxy = [NSURL URLWithString:[prefix stringByAppendingString:encoded]];
			NSCAssert([[[RFPhotoZoomController normalizedImageURL:proxy] absoluteString] isEqualToString:original_url], @"Expand the proxy without removing size components from the actual image URL");
		}
		NSCAssert([RFPhotoZoomController normalizedImageURL:nil] == nil, @"Nil URLs are safe");
		NSURL* plain = [NSURL URLWithString:original_url];
		NSCAssert([[RFPhotoZoomController normalizedImageURL:plain] isEqual:plain], @"Do not rewrite direct URLs");

		RFPhotoZoomController* viewer = [[RFPhotoZoomController alloc] initWithURL:original_url altText:@"A \"mountain's\" photo" allowCopy:YES];
		[viewer loadWindow];
		NSCAssert(viewer.isWindowLoaded && viewer.window.toolbar != nil, @"Create a real window and toolbar without the old nib");
		NSCAssert(viewer.window.delegate == viewer && viewer.window.tabbingMode == NSWindowTabbingModeDisallowed, @"Keep photo windows independent");
		NSCAssert((viewer.window.collectionBehavior & NSWindowCollectionBehaviorFullScreenPrimary) != 0, @"Allow native full screen");
		NSCAssert([viewer.window.frameAutosaveName isEqualToString:@"PhotoZoomWindow"], @"Retain the existing window frame preference");
		NSCAssert([viewer.scrollView.gestureRecognizers containsObject:viewer.magnificationGestureRecognizer], @"Install the pinch gesture alongside AppKit's own scroll gestures");
		NSCAssert(viewer.imageView.animates && [viewer.imageView.accessibilityLabel isEqualToString:viewer.photoAlt], @"Retain animated image support and accessibility text");
		NSArray* items = [viewer toolbarDefaultItemIdentifiers:viewer.window.toolbar];
		NSCAssert(items.count == 4 && [items.lastObject isEqualToString:@"MicroblogPhotoToolbarCopyHTML"], @"Keep Copy HTML in the toolbar when permitted");
		NSToolbarItem* zoom_in = [[NSToolbarItem alloc] initWithItemIdentifier:@"MicroblogPhotoToolbarZoomIn"];
		NSToolbarItem* zoom_out = [[NSToolbarItem alloc] initWithItemIdentifier:@"MicroblogPhotoToolbarZoomOut"];
		NSCAssert(![viewer validateToolbarItem:zoom_in] && ![viewer validateToolbarItem:zoom_out], @"Zoom stays disabled until an image is loaded");

		[viewer.window setContentSize:NSMakeSize(640, 480)];
		NSImage* image = fixture_image();
		[viewer revealLoadedImage:image];
		NSCAssert(viewer.zoomScale <= 1 && NSWidth(viewer.imageView.frame) <= NSWidth(viewer.scrollView.contentView.bounds) + 1, @"Initially fit the image without upscaling it");
		NSCAssert([viewer validateToolbarItem:zoom_in], @"Enable zoom after loading");
		NSCAssert(toolbar_item(viewer, zoom_in.itemIdentifier).enabled, @"Immediately enable the actual toolbar control after loading");
		CGFloat fit_scale = viewer.zoomScale;
		[viewer zoomIn:nil];
		NSCAssert(fabs(viewer.zoomScale - fit_scale * 1.25) < 0.0001, @"Use Inkwell's toolbar zoom step");
		[viewer zoomOut:nil];
		NSCAssert(fabs(viewer.zoomScale - fit_scale) < 0.0001, @"Zooming back preserves the scale");
		viewer.zoomScale = 1;
		[viewer updateImageLayout];
		[viewer scrollToKeepImageRelativeCenterPoint:NSMakePoint(0.6, 0.4)];
		NSPoint center = [viewer currentImageRelativeCenterPoint];
		[viewer zoomIn:nil];
		NSPoint zoomed_center = [viewer currentImageRelativeCenterPoint];
		NSCAssert(fabs(center.x - zoomed_center.x) < 0.003 && fabs(center.y - zoomed_center.y) < 0.003, @"Keep the same part of the photo centered");

		TestMagnificationGesture* gesture = [[TestMagnificationGesture alloc] initWithTarget:nil action:NULL];
		gesture.testState = NSGestureRecognizerStateBegan;
		gesture.magnification = 0;
		[viewer handleMagnificationGesture:gesture];
		CGFloat start_scale = viewer.zoomScale;
		gesture.testState = NSGestureRecognizerStateChanged;
		gesture.magnification = 0.5;
		[viewer handleMagnificationGesture:gesture];
		NSCAssert(fabs(viewer.zoomScale - start_scale * 1.5) < 0.0001, @"Pinch applies cumulative magnification from the gesture start");
		gesture.testState = NSGestureRecognizerStateEnded;
		gesture.magnification = 100;
		[viewer handleMagnificationGesture:gesture];
		NSCAssert(viewer.zoomScale == 8 && ![viewer validateToolbarItem:zoom_in], @"Clamp maximum zoom and disable its toolbar item");
		NSCAssert(!toolbar_item(viewer, zoom_in.itemIdentifier).enabled, @"Update the actual control at maximum zoom");
		for (NSInteger i = 0; i < 80; i++) { [viewer zoomOut:nil]; }
		NSCAssert(fabs(viewer.zoomScale - [viewer minimumZoomScaleForCurrentViewport]) < 0.0001 && ![viewer validateToolbarItem:zoom_out], @"Clamp minimum zoom");
		test_panning();

		test_pasteboard = [NSPasteboard pasteboardWithUniqueName];
		Method general = class_getClassMethod([NSPasteboard class], @selector(generalPasteboard));
		Method isolated = class_getClassMethod([NSPasteboard class], @selector(viewerTestPasteboard));
		method_exchangeImplementations(general, isolated);
		[viewer copyHTML:viewer];
		method_exchangeImplementations(general, isolated);
		NSString* html = [test_pasteboard stringForType:NSPasteboardTypeString];
		NSCAssert([html containsString:original_url] && [html containsString:@"alt=\"A mountains photo\""] && [viewer.htmlCopyButton.title isEqualToString:@"✓ Copied"], @"Copy HTML keeps original URLs, legacy alt quoting, and confirmation without changing the user's clipboard");
		[test_pasteboard releaseGlobally];

		RFPhotoZoomController* remote = [[RFPhotoZoomController alloc] initWithURL:@"https://photo-viewer.test/good" altText:nil allowCopy:NO];
		[remote showWindow:nil];
		NSCAssert([remote toolbarDefaultItemIdentifiers:remote.window.toolbar].count == 2, @"Do not offer Copy HTML for timeline photos");
		NSCAssert(!remote.progressIndicator.hidden, @"Show progress while fetching the image");
		NSData* data = image.TIFFRepresentation;
		respond(@"/good", 200, data);
		spin_until(^BOOL { return remote.imageView.image != nil && remote.progressIndicator.hidden; });
		NSCAssert([remote.window.title isEqualToString:@"photo-viewer.test"] && NSWidth(remote.window.frame) <= 800 && NSHeight(remote.window.frame) <= 800, @"Use the image host and Inkwell's automatic size cap");
		for (NSString* path in @[@"/bad-http", @"/bad-image"]) {
			[remote loadImageURL:[NSURL URLWithString:[@"https://photo-viewer.test" stringByAppendingString:path]]];
			respond(path, [path isEqualToString:@"/bad-http"] ? 502 : 200, [path isEqualToString:@"/bad-http"] ? data : [@"not an image" dataUsingEncoding:NSUTF8StringEncoding]);
			spin_until(^BOOL { return remote.progressIndicator.hidden; });
			NSCAssert(remote.imageView.image == nil, @"Failed responses do not reveal an image or leave the spinner running");
		}
		[remote loadImageURL:[NSURL URLWithString:@"https://photo-viewer.test/older"]];
		respond(@"/older", 200, data);
		spin_until(^BOOL { return remote.imageTask == nil; });
		[remote loadImageURL:[NSURL URLWithString:@"https://photo-viewer.test/latest"]];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
		NSCAssert(remote.imageView.image == nil && !remote.progressIndicator.hidden, @"Do not reveal an older image when its resize animation finishes");
		respond(@"/latest", 200, data);
		spin_until(^BOOL { return remote.imageView.image != nil && remote.progressIndicator.hidden; });

		[viewer showWindow:nil];
		respond(@"/images/600/picture.png", 200, data);
		spin_until(^BOOL { return viewer.imageView.image != nil && viewer.progressIndicator.hidden; });
		CGFloat light_background = validate_appearance(viewer, NSAppearanceNameAqua);
		CGFloat dark_background = validate_appearance(viewer, NSAppearanceNameDarkAqua);
		NSCAssert(light_background > dark_background + 0.3, @"Adapt the titlebar background for dark mode");
		__block NSInteger closed = 0;
		id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPhotoWindowDidCloseNotification object:remote queue:nil usingBlock:^(NSNotification* note) { closed++; }];
		[remote loadImageURL:[NSURL URLWithString:@"https://photo-viewer.test/cancel"]];
		spin_until(^BOOL { return pending_requests[@"/cancel"] != nil; });
		NSURLSessionDataTask* task = remote.imageTask;
		NSInteger cancellations_before = cancelled_requests;
		[remote close];
		spin_until(^BOOL { return cancelled_requests > cancellations_before; });
		NSCAssert(closed == 1 && remote.imageTask == nil && (task.state == NSURLSessionTaskStateCanceling || task.state == NSURLSessionTaskStateCompleted), @"Closing cancels the request and notifies Micro.blog exactly once");
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
		[viewer close];
		MBVideoZoomController* video = [[MBVideoZoomController alloc] initWithURL:@"https://example.com/movie.mp4"];
		NSCAssert(![video isKindOfClass:[RFPhotoZoomController class]] && [video.windowNibName isEqualToString:@"VideoZoom"], @"The video viewer retains its own nib and does not initialize the photo UI");
		[NSURLProtocol unregisterClass:[TestImageProtocol class]];
		NSLog(@"Photo viewer layout, toolbar zoom, pinch, panning, Copy HTML, loading, cancellation, and video isolation tests passed.");
	}
	return 0;
}
