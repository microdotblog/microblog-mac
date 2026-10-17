# Run with: ruby Tests/uploads_description_notice_test.rb /path/to/Micro.blog.app
# Exercise the production AppKit notice without opening the app or networking.
require 'tmpdir'

root = File.expand_path('..', __dir__)
uploads = File.read(File.join(root, 'Source/RFAllUploadsController.m'))
notice_class = uploads[/@interface MBUploadDescriptionNotice .*?@end\n\n@implementation MBUploadDescriptionNotice.*?@end/m] or abort 'Missing notice view'
methods = %w[setupDescriptionReadyNotice showDescriptionReadyNotice hideDescriptionReadyNotice].map do |name|
	uploads[/^- \(void\) #{name}\n\{.*?^\}/m] or abort "Missing #{name}"
end.join("\n").gsub('RFAllUploadsController', 'TestController')
abort 'Hide notice when leaving Uploads' unless uploads[/^- \(void\) viewDidDisappear.*?^\}/m].include?('[self hideDescriptionReadyNotice]')
abort 'Hide notice when switching blogs' unless uploads[/^- \(void\) updatedBlogNotification:.*?^\}/m].include?('[self hideDescriptionReadyNotice]')

source = <<~OBJC
	#import <Cocoa/Cocoa.h>
	#import <objc/runtime.h>
	#import "NSAppearance+Extras.h"
	static NSBundle* assets_bundle;
	@interface NSColor (NoticeTestAssets)
	+ (NSColor *) noticeTestColorNamed:(NSColorName)name;
	@end
	@implementation NSColor (NoticeTestAssets)
	+ (NSColor *) noticeTestColorNamed:(NSColorName)name
	{
		return [NSColor colorNamed:name bundle:assets_bundle];
	}
	@end
	#{notice_class}
	@interface TestController : NSViewController
	@property (strong) NSCollectionView* collectionView;
	@property (strong) MBUploadDescriptionNotice* descriptionNotice;
	@property (strong) NSTimer* descriptionNoticeTimer;
	@property NSInteger descriptionNoticeGeneration;
	- (void) setupDescriptionReadyNotice;
	- (void) showDescriptionReadyNotice;
	- (void) hideDescriptionReadyNotice;
	@end
	@implementation TestController
	#{methods}
	@end
	static void FinishAnimations(void)
	{
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
	}
	static void FireTimer(NSTimer* timer)
	{
		[timer fire];
		[timer invalidate];
	}
	int main(int argc, const char* argv[])
	{
		@autoreleasepool {
			[NSApplication sharedApplication];
			NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
			assets_bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
			NSCAssert(assets_bundle != nil, @"Provide the built app for its color assets");
			method_exchangeImplementations(class_getClassMethod([NSColor class], @selector(colorNamed:)), class_getClassMethod([NSColor class], @selector(noticeTestColorNamed:)));
			NSCAssert([NSColor colorNamed:@"color_notification_background"] != nil, @"Use the actual publishing background asset");
			TestController* controller = [TestController new];
			controller.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 360)];
			controller.view.wantsLayer = YES;
			NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 700, 310)];
			scroll.wantsLayer = YES;
			scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
			controller.collectionView = [[NSCollectionView alloc] initWithFrame:scroll.bounds];
			for (NSInteger i = 0; i < 6; i++) {
				NSImageView* photo = [[NSImageView alloc] initWithFrame:NSMakeRect(18 + i * 110, 0, 96, 110)];
				photo.wantsLayer = YES;
				photo.image = [NSImage imageWithSize:photo.bounds.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
					[[NSColor colorWithRed:0.25 green:0.4 blue:0.2 alpha:1] setFill];
					NSRectFill(rect);
					[[NSColor colorWithRed:0.6 green:0.35 blue:0.15 alpha:1] setFill];
					NSRectFill(NSMakeRect(0, 35, rect.size.width, 35));
					return YES;
				}];
				[controller.collectionView addSubview:photo];
			}
			scroll.documentView = controller.collectionView;
			[controller.view addSubview:scroll];
			[controller showDescriptionReadyNotice];
			FinishAnimations();
			[controller.view layoutSubtreeIfNeeded];
			MBUploadDescriptionNotice* notice = controller.descriptionNotice;
			[notice displayIfNeeded];
			NSTextField* label = notice.subviews.firstObject;
			NSCAssert([label.stringValue isEqualToString:@"Finished generating photo description."], @"Requested message");
			NSCAssert(label.font.pointSize == [NSFont systemFontSize], @"Match publishing pane text size");
			NSCAssert(notice.layer.cornerRadius > 0 && notice.layer.masksToBounds, @"Rounded, explicitly inset content");
			NSCAssert(notice.layer.backgroundColor && fabs(CGColorGetAlpha(notice.layer.backgroundColor) - 0.9) < 0.001, @"Paint the actual background layer at ninety percent opacity");
			NSCAssert(NSMaxX(notice.frame) == 690 && NSMaxY(notice.frame) == 300, @"Inset top-right of the scroll viewport");
			NSRect label_alignment = [label alignmentRectForFrame:label.frame];
			NSCAssert(NSMinX(label_alignment) >= 12 && NSMinY(label_alignment) >= 10, @"Padding inside the rounded box");
			NSCAssert([notice hitTest:NSMakePoint(15, 15)] == nil, @"Never block photo clicks underneath");
			NSTimeInterval seconds_remaining = controller.descriptionNoticeTimer.fireDate.timeIntervalSinceNow;
			NSCAssert(seconds_remaining > 4 && seconds_remaining <= 5, @"Wait five seconds before fading");
			NSTimer* old_timer = controller.descriptionNoticeTimer;
			[controller showDescriptionReadyNotice];
			NSCAssert(!old_timer.valid && controller.descriptionNoticeTimer != old_timer, @"Another completion restarts the five-second timer");

			for (NSAppearanceName name in @[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]) {
				NSApp.appearance = [NSAppearance appearanceNamed:name];
				controller.view.appearance = NSApp.appearance;
				[controller.view layoutSubtreeIfNeeded];
				[controller.view displayIfNeeded];
				[notice displayIfNeeded];
				[notice.effectiveAppearance performAsCurrentDrawingAppearance:^{
					NSColor* expected_color = [[[NSColor colorNamed:@"color_notification_background"] colorWithAlphaComponent:0.9] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
					NSColor* painted_color = [[NSColor colorWithCGColor:notice.layer.backgroundColor] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
					NSCAssert(fabs(expected_color.redComponent - painted_color.redComponent) < 0.001 && fabs(expected_color.blueComponent - painted_color.blueComponent) < 0.001, @"Repaint the background when switching appearance");
				}];
				[controller.view.effectiveAppearance performAsCurrentDrawingAppearance:^{
					NSBitmapImageRep* bitmap = [controller.view bitmapImageRepForCachingDisplayInRect:controller.view.bounds];
					[controller.view cacheDisplayInRect:controller.view.bounds toBitmapImageRep:bitmap];
					NSString* filename = [name isEqualToString:NSAppearanceNameAqua] ? @"/private/tmp/microblog-upload-description-light.png" : @"/private/tmp/microblog-upload-description-dark.png";
					[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:filename atomically:YES];
				}];
			}
			controller.view.frame = NSMakeRect(0, 0, 280, 360);
			[controller.view layoutSubtreeIfNeeded];
			NSCAssert(NSMinX(notice.frame) >= 18 && NSMaxX(notice.frame) <= 270, @"Fit a narrow window without overflowing");
			FireTimer(controller.descriptionNoticeTimer);
			FinishAnimations();
			NSCAssert(notice.hidden && notice.alphaValue == 0, @"Fade and hide after the timer fires");
			[controller showDescriptionReadyNotice];
			FireTimer(controller.descriptionNoticeTimer);
			[controller showDescriptionReadyNotice];
			FinishAnimations();
			NSCAssert(!notice.hidden && notice.alphaValue == 1, @"A stale fade cannot hide a new completion notice");
			[controller hideDescriptionReadyNotice];
			NSCAssert(notice.hidden && controller.descriptionNoticeTimer == nil, @"Leaving the pane cancels its notice");
			NSLog(@"Uploads description notice tests passed.");
		}
		return 0;
	}
OBJC

abort 'Provide the built Micro.blog.app path' unless ARGV[0]
Dir.mktmpdir('microblog-notice-tests-') do |directory|
	path = File.join(directory, 'notice.m')
	binary = File.join(directory, 'notice')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-I', File.join(root, 'Source'), '-framework', 'Cocoa', path, File.join(root, 'Source/NSAppearance+Extras.m'), '-o', binary)
	abort 'Notice tests failed' unless system(binary, File.expand_path(ARGV[0]))
end
