# Run with: ruby Tests/table_row_context_menu_test.rb
# Check AppKit hit testing before asking the hit view for a context menu.
require 'tmpdir'

root = File.expand_path('..', __dir__)
source = <<~'OBJC'
	#import <Cocoa/Cocoa.h>
	#import "MBBooksTableView.h"
	#import "MBMoviesTableView.h"

	static NSEvent* test_event;

	@interface TestApplication : NSApplication
	@end
	@implementation TestApplication
	- (NSEvent *) currentEvent
	{
		return test_event ?: [super currentEvent];
	}
	@end

	@interface TestRows : NSObject <NSTableViewDelegate, NSTableViewDataSource>
	@property NSInteger buttonActions;
	@end
	@implementation TestRows
	- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
	{
		return 2;
	}
	- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
	{
		return nil;
	}
	- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
	{
		NSTableRowView* view = [[NSTableRowView alloc] initWithFrame:NSMakeRect(0, 0, 440, 90)];
		NSTextField* title = [NSTextField labelWithString:@"Title"];
		title.frame = NSMakeRect(90, 50, 180, 20);
		[view addSubview:title];
		NSTextField* details = [NSTextField labelWithString:@"Details"];
		details.frame = NSMakeRect(90, 20, 180, 20);
		[view addSubview:details];
		NSImageView* image = [[NSImageView alloc] initWithFrame:NSMakeRect(15, 10, 60, 60)];
		[view addSubview:image];
		NSButton* button = [NSButton buttonWithTitle:@"New Post..." target:self action:@selector(buttonClicked:)];
		button.frame = NSMakeRect(285, 30, 105, 25);
		[view addSubview:button];
		NSButton* options = [NSButton buttonWithTitle:@"..." target:self action:@selector(buttonClicked:)];
		options.frame = NSMakeRect(395, 30, 30, 25);
		[view addSubview:options];
		return view;
	}
	- (void) buttonClicked:(id)sender
	{
		self.buttonActions++;
	}
	@end

	int main(void)
	{
		@autoreleasepool {
			[TestApplication sharedApplication];
			for (Class table_class in @[MBBooksTableView.class, MBMoviesTableView.class]) {
				for (NSInteger selection = -1; selection < 2; selection++) {
					for (NSInteger click = 0; click < 3; click++) {
						// Fresh tables prevent menu-tracking highlight views from affecting later cases.
						NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
						NSTableView* table = [[table_class alloc] initWithFrame:window.contentView.bounds];
						table.headerView = nil;
						table.rowHeight = 90;
						table.intercellSpacing = NSZeroSize;
						NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"content"];
						column.width = 440;
						[table addTableColumn:column];
						[window.contentView addSubview:table];
						TestRows* owner = [TestRows new];
						table.delegate = owner;
						table.dataSource = owner;
						table.target = owner;
						table.doubleAction = @selector(buttonClicked:);
						table.menu = [NSMenu new];
						[table.menu addItemWithTitle:@"New Post..." action:NULL keyEquivalent:@""];
						[table reloadData];
						[window.contentView layoutSubtreeIfNeeded];
						if (selection >= 0) {
							[table selectRowIndexes:[NSIndexSet indexSetWithIndex:selection] byExtendingSelection:NO];
						}
						NSTableRowView* row = [table rowViewAtRow:1 makeIfNecessary:YES];
						NSArray* regions = [@[row] arrayByAddingObjectsFromArray:row.subviews];
						NSView* hit = nil;
						for (NSView* region in regions) {
							NSPoint point = region == row ? NSMakePoint(5, 5) : NSMakePoint(NSMidX(region.bounds), NSMidY(region.bounds));
							NSPoint window_point = [region convertPoint:point toView:nil];
							test_event = [NSEvent mouseEventWithType:click == 1 ? NSEventTypeRightMouseDown : NSEventTypeLeftMouseDown location:window_point modifierFlags:click == 2 ? NSEventModifierFlagControl : 0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
							hit = [table hitTest:[region convertPoint:point toView:table.superview]];
							if (click > 0) {
								NSCAssert(hit == table, @"%@ context click over %@ must reach the table, got %@", table_class, region.className, hit.className);
							}
							else if ([region isKindOfClass:[NSButton class]]) {
								NSCAssert(hit == region || [hit isDescendantOf:region], @"Primary clicks must still reach buttons");
								[(NSButton *)region performClick:nil];
							}
							else {
								NSCAssert(hit == table || hit == row, @"Static labels and images must leave primary clicks with the table or row, got %@", hit.className);
							}
						}
						if (click > 0) {
							NSCAssert(owner.buttonActions == 0, @"Context clicks must not invoke a button action");
							NSCAssert([hit menuForEvent:test_event] == table.menu, @"The hit view must supply the table menu");
							NSCAssert(table.selectedRow == 1, @"Menu preparation must select the clicked row");
							NSCAssert(window.firstResponder == table, @"Context clicks must focus the table");
						}
						else {
							NSCAssert(owner.buttonActions == 2, @"Both primary button actions must fire once");
						}
						test_event = nil;
					}
				}
			}
			NSLog(@"Books and movies row context-menu routing checks passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-row-context-menu-') do |directory|
	path = File.join(directory, 'routing.m')
	binary = File.join(directory, 'routing')
	File.write(path, source)
	sources = ['MBBooksTableView.m', 'MBMoviesTableView.m'].map { |name| File.join(root, 'Source', name) }
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Cocoa', '-I', File.join(root, 'Source'), path, *sources, '-o', binary)
	abort 'Row context-menu checks failed' unless system(binary)
end
