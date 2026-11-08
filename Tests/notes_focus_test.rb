# Run with: ruby Tests/notes_focus_test.rb
# Exercise the real pane-presentation method with an offscreen AppKit window.
require 'tmpdir'

timeline = File.read(File.expand_path('../Source/RFTimelineController.m', __dir__))
method = timeline[/^- \(void\) showRootController:.*?^\}/m]
abort 'Missing showRootController' unless method

source = <<~'OBJC'
	#import <Cocoa/Cocoa.h>
	static NSMutableArray* main_queue;
	#define RFDispatchMainAsync(...) [main_queue addObject:[(__VA_ARGS__) copy]]

	@interface MBBookmarksController : NSViewController
	@property BOOL didFocusContent;
	@end
	@implementation MBBookmarksController
	- (void) focusContent { self.didFocusContent = YES; }
	@end

	@interface TestTimeline : NSObject
	@property (strong) NSWindow* window;
	@property (strong) NSView* containerView;
	@property (strong) NSView* timelineLayoutView;
	@property (strong) NSViewController* rootController;
	@end
	@implementation TestTimeline
	- (void) hideHoveredLink {}
	- (void) addResizeConstraintsToOverlay:(NSView *)view containerView:(NSView *)container {}
	- (void) updateToolbarScrimVisibility {}
	__METHOD__
	@end

	static NSViewController* newPane(void)
	{
		NSViewController* controller = [NSViewController new];
		controller.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 500)];
		return controller;
	}

	static void applyFocusUpdates(void)
	{
		while (main_queue.count > 0) {
			void (^block)(void) = main_queue.firstObject;
			[main_queue removeObjectAtIndex:0];
			block();
		}
	}

	int main(void)
	{
		@autoreleasepool {
			[NSApplication sharedApplication];
			main_queue = [NSMutableArray array];
			TestTimeline* timeline = [TestTimeline new];
			timeline.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 500) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			timeline.containerView = timeline.window.contentView;
			timeline.timelineLayoutView = [[NSView alloc] initWithFrame:timeline.containerView.bounds];
			[timeline.containerView addSubview:timeline.timelineLayoutView];

			NSViewController* notes = newPane();
			NSTextView* editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 350, 500)];
			[notes.view addSubview:editor];
			[timeline showRootController:notes];
			NSCAssert([timeline.window makeFirstResponder:editor], @"New Note can initially focus its editor");
			applyFocusUpdates();
			NSCAssert(timeline.window.firstResponder == editor, @"Deferred pane focus must not take focus away from the new note editor");

			// The toolbar reopens the same Notes pane before creating the next note.
			[timeline showRootController:notes];
			[timeline.window makeFirstResponder:editor];
			applyFocusUpdates();
			NSCAssert(timeline.window.firstResponder == editor, @"Repeated New Note keeps keyboard focus in the editor");

			// A queued callback for a pane that was left must not steal focus either.
			[timeline showRootController:notes];
			[notes.view removeFromSuperview];
			NSViewController* other = newPane();
			NSTextView* other_editor = [[NSTextView alloc] initWithFrame:editor.frame];
			[other.view addSubview:other_editor];
			[timeline showRootController:other];
			[timeline.window makeFirstResponder:other_editor];
			applyFocusUpdates();
			NSCAssert(timeline.window.firstResponder == other_editor, @"Old navigation callbacks cannot override the current pane's focus");

			[other.view removeFromSuperview];
			MBBookmarksController* bookmarks = [MBBookmarksController new];
			bookmarks.view = [[NSView alloc] initWithFrame:timeline.containerView.bounds];
			[timeline.window makeFirstResponder:nil];
			[timeline showRootController:bookmarks];
			applyFocusUpdates();
			NSCAssert(bookmarks.didFocusContent, @"Keep the usual content focus when a pane has not focused a child");
			NSLog(@"Notes focus tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-notes-focus-') do |directory|
	path = File.join(directory, 'focus.m')
	binary = File.join(directory, 'focus')
	File.write(path, source.sub('__METHOD__') { method })
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Cocoa', path, '-o', binary)
	abort 'Notes focus tests failed' unless system(binary)
end
