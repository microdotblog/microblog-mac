#import <Cocoa/Cocoa.h>
#import "MBReaderController.h"

@interface MBReaderController (Testing)
- (void) loadReader;
@end

static NSMutableArray* gCreatedReaders;

@interface MBReaderTestController : MBReaderController
@property (assign, nonatomic) BOOL requestedReader;
@end

@implementation MBReaderTestController
- (void) loadReader
{
	// Exercise real window setup without sending a request or using a signed-in session.
	self.requestedReader = YES;
	[gCreatedReaders addObject:self];
}
@end

// Link with MBReaderController.m, Cocoa and WebKit. Pass --windows for AppKit lifecycle checks.
int main(int argc, const char* argv[])
{
	@autoreleasepool {
		NSArray* reader_urls = @[
			@"https://micro.blog/bookmarks/9289244",
			@"https://micro.blog/bookmarks/9289244/",
			@"https://micro.blog/bookmarks/9289244?source=bookmarks#highlight",
			@"http://micro.blog/bookmarks/9289244",
			@"https://MICRO.BLOG/bookmarks/9289244"
		];
		for (NSString* url_string in reader_urls) {
			NSString* bookmark_id = [MBReaderController bookmarkIDForURL:[NSURL URLWithString:url_string]];
			NSCAssert([bookmark_id isEqualToString:@"9289244"], @"Expected a reader ID for %@", url_string);
		}
		NSArray* other_urls = @[
			@"https://example.com/bookmarks/9289244",
			@"https://micro.blog.example.com/bookmarks/9289244",
			@"https://micro.blog",
			@"https://micro.blog/bookmarks",
			@"https://micro.blog/bookmarks/links",
			@"https://micro.blog/bookmarks/9289244/highlights",
			@"https://micro.blog/hybrid/bookmarks/9289244",
			@"https://micro.blog/manton/9289244",
			@"ftp://micro.blog/bookmarks/9289244"
		];
		for (NSString* url_string in other_urls) {
			NSCAssert([MBReaderController bookmarkIDForURL:[NSURL URLWithString:url_string]] == nil, @"Unexpected reader ID for %@", url_string);
		}
		NSLog(@"Passed 14 reader URL-routing checks.");
		if (argc > 1 && strcmp(argv[1], "--windows") == 0) {
			[NSApplication sharedApplication];
			NSCAssert(NSScreen.mainScreen != nil, @"Window lifecycle checks require access to the macOS WindowServer");
			gCreatedReaders = [NSMutableArray array];
			NSString* first_id = [NSString stringWithFormat:@"test-%@", NSUUID.UUID.UUIDString];
			NSString* second_id = [NSString stringWithFormat:@"test-%@", NSUUID.UUID.UUIDString];
			[MBReaderTestController showReaderWithBookmarkID:first_id];
			MBReaderTestController* first = gCreatedReaders.lastObject;
			NSCAssert(first.window != nil && first.window.visible, @"Reader window must exist and be visible");
			NSCAssert(first.requestedReader && first.window.contentView.subviews.count == 1, @"Reader must initialize its web view and request");
			NSSize content_size = first.window.contentView.frame.size;
			NSCAssert(content_size.width == 700 && content_size.height <= 800 && content_size.height > 300, @"Unexpected default content size");
			NSString* autosave_name = [@"Reader-" stringByAppendingString:first_id];
			NSCAssert([first.window.frameAutosaveName isEqualToString:autosave_name], @"Window assignment must preserve autosaving");
			[first.window orderOut:nil];
			[MBReaderTestController showReaderWithBookmarkID:first_id];
			NSCAssert(gCreatedReaders.count == 1 && first.window.visible, @"Opening the same ID must show the existing window");
			[MBReaderTestController showReaderWithBookmarkID:second_id];
			MBReaderTestController* second = gCreatedReaders.lastObject;
			NSCAssert(gCreatedReaders.count == 2 && second.window != first.window, @"Different IDs need separate windows");
			NSRect saved_frame = NSMakeRect(80, 100, 620, 640);
			[first.window setFrame:saved_frame display:NO];
			[first close];
			[MBReaderTestController showReaderWithBookmarkID:first_id];
			MBReaderTestController* reopened = gCreatedReaders.lastObject;
			NSCAssert(gCreatedReaders.count == 3 && reopened != first && reopened.window.visible, @"Closing must remove the reader from the registry");
			NSCAssert(NSEqualRects(reopened.window.frame, saved_frame), @"Reopening must restore the saved frame");
			[reopened close];
			[second close];
			[NSWindow removeFrameUsingName:autosave_name];
			[NSWindow removeFrameUsingName:[@"Reader-" stringByAppendingString:second_id]];
			NSLog(@"Passed reader window creation, reuse, close/reopen, and frame-autosave checks.");
		}
	}
	return 0;
}
