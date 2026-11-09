# Run with: ruby Tests/movies_context_menu_test.rb
# Exercise the real table and menu validation with an offscreen AppKit window.
require 'tmpdir'

root = File.expand_path('..', __dir__)
controller = File.read(File.join(root, 'Source/MBMoviesController.m'))
methods = ['menuNeedsUpdate', 'validateMenuItem'].map do |name|
	controller[/^- \([^\n]+\) #{name}:.*?^\}/m] or abort "Missing #{name}"
end.join("\n")

source = <<~OBJC
	#import <Cocoa/Cocoa.h>
	#import "MBMoviesTableView.h"
	@interface MBMovie : NSObject
	@property (copy) NSString* username;
	@property (copy) NSString* postText;
	@end
	@implementation MBMovie
	@end
	@interface TestController : NSObject <NSTableViewDataSource, NSMenuDelegate, NSMenuItemValidation>
	@property (strong) NSTableView* tableView;
	@property (strong) NSArray* movies;
	- (void) startNewPost:(id)sender;
	@end
	@implementation TestController
	- (void) startNewPost:(id)sender {}
	- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView { return self.movies.count; }
	- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row { return @""; }
	#{methods}
	@end

	static NSEvent* clickEvent(NSTableView* table, NSInteger row, BOOL controlClick)
	{
		NSRect rect = [table rectOfRow:row];
		NSPoint point = [table convertPoint:NSMakePoint(NSMidX(rect), NSMidY(rect)) toView:nil];
		return [NSEvent mouseEventWithType:controlClick ? NSEventTypeLeftMouseDown : NSEventTypeRightMouseDown location:point modifierFlags:controlClick ? NSEventModifierFlagControl : 0 timestamp:0 windowNumber:table.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
	}

	static void checkMenu(TestController* controller, NSInteger row, BOOL controlClick, BOOL available)
	{
		NSTableView* table = controller.tableView;
		NSMenu* menu = [table menuForEvent:clickEvent(table, row, controlClick)];
		NSCAssert(menu == table.menu, @"The row supplies its context menu");
		NSCAssert(table.selectedRow == row, @"The clicked row must be selected before preparing the menu");
		NSCAssert(table.window.firstResponder == table, @"Right-click focuses the table for the selected-row appearance");
		// Prepare the menu without entering AppKit's interactive menu-tracking loop.
		[controller menuNeedsUpdate:menu];
		[menu update];
		NSCAssert([menu itemAtIndex:0].hidden == !available, @"New Post availability follows the newly selected row");
		NSCAssert([menu itemAtIndex:1].hidden == !available, @"The separator follows New Post visibility");
	}

	int main(void)
	{
		@autoreleasepool {
			[NSApplication sharedApplication];
			NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			MBMoviesTableView* table = [[MBMoviesTableView alloc] initWithFrame:window.contentView.bounds];
			table.headerView = nil;
			table.rowHeight = 50;
			NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"movie"];
			column.width = 400;
			[table addTableColumn:column];
			[window.contentView addSubview:table];

			MBMovie* discovery = [MBMovie new];
			discovery.username = @"reader";
			MBMovie* movie = [MBMovie new];
			movie.postText = @"Watching a movie";
			MBMovie* episode = [MBMovie new];
			episode.postText = @"Watching an episode";
			TestController* controller = [TestController new];
			controller.tableView = table;
			controller.movies = @[discovery, movie, episode];
			table.dataSource = controller;
			[table reloadData];
			table.menu = [NSMenu new];
			table.menu.delegate = controller;
			NSMenuItem* post = [table.menu addItemWithTitle:@"New Post..." action:@selector(startNewPost:) keyEquivalent:@""];
			post.target = controller;
			[table.menu addItem:[NSMenuItem separatorItem]];
			[table.menu addItemWithTitle:@"Copy Link" action:NULL keyEquivalent:@""];

			[table deselectAll:nil];
			checkMenu(controller, 1, NO, YES);
			checkMenu(controller, 0, NO, NO);
			checkMenu(controller, 2, NO, YES);
			checkMenu(controller, 0, YES, NO);
			checkMenu(controller, 1, YES, YES);
			NSPoint blank_point = [table convertPoint:NSMakePoint(20, 250) toView:nil];
			NSEvent* blank_click = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:blank_point modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
			NSCAssert([table menuForEvent:blank_click] == nil, @"Empty space must not offer actions for a previously selected movie");
			NSLog(@"Movies context menu selection and visibility checks passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-movies-menu-') do |directory|
	path = File.join(directory, 'menu.m')
	binary = File.join(directory, 'menu')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Cocoa', '-I', File.join(root, 'Source'), path, File.join(root, 'Source/MBMoviesTableView.m'), '-o', binary)
	abort 'Movies context menu checks failed' unless system(binary)
end
