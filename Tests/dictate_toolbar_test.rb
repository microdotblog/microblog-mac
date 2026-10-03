# Run with: ruby Tests/dictate_toolbar_test.rb
# Exercise production toolbar methods with a fake toolbar and account setting.
require 'tmpdir'

root = File.expand_path('..', __dir__)
timeline = File.read(File.join(root, 'Source/RFTimelineController.m'))
update = timeline[/^- \(void\) updateToolbarForSidebarSelection.*?^\}/m] or abort 'Toolbar update not found'
# The fake toolbar intentionally uses an untyped array instead of AppKit's typed items.
update = update.gsub('toolbar.items[i].itemIdentifier', '[toolbar.items[i] itemIdentifier]')
defaults = timeline[/^- \(NSArray<NSToolbarItemIdentifier> \*\) toolbarDefaultItemIdentifiers:.*?^\}/m] or abort 'Toolbar defaults not found'

source = <<~OBJC
	#import <Foundation/Foundation.h>
	typedef NSString* NSToolbarItemIdentifier;
	static NSString* const NSToolbarFlexibleSpaceItemIdentifier = @"FlexibleSpace";
	static NSString* const kIsUsingAI = @"IsUsingAI";
	static NSInteger const kSelectionUploads = 8, kSelectionNotes = 13;
	static BOOL uses_ai;
	@interface RFSettings : NSObject
	+ (BOOL) boolForKey:(NSString *)key;
	@end
	@implementation RFSettings
	+ (BOOL) boolForKey:(NSString *)key { return uses_ai; }
	@end
	@interface TestItem : NSObject
	@property (copy) NSString* itemIdentifier;
	@end
	@implementation TestItem
	@end
	@interface NSToolbar : NSObject
	@property (strong) NSMutableArray* items;
	- (void) removeItemAtIndex:(NSInteger)index;
	- (void) insertItemWithItemIdentifier:(NSString *)identifier atIndex:(NSInteger)index;
	@end
	@implementation NSToolbar
	- (void) removeItemAtIndex:(NSInteger)index { [self.items removeObjectAtIndex:index]; }
	- (void) insertItemWithItemIdentifier:(NSString *)identifier atIndex:(NSInteger)index
	{
		TestItem* item = [TestItem new];
		item.itemIdentifier = identifier;
		[self.items insertObject:item atIndex:index];
	}
	@end
	@interface TestWindow : NSObject
	@property (strong) NSToolbar* toolbar;
	@end
	@implementation TestWindow
	@end
	@interface TestController : NSObject
	@property NSInteger selectedTimeline;
	@property (strong) TestWindow* window;
	@end
	@implementation TestController
	#{update}
	#{defaults}
	@end
	int main(void)
	{
		@autoreleasepool {
			TestController* controller = [TestController new];
			controller.selectedTimeline = kSelectionNotes;
			controller.window = [TestWindow new];
			NSToolbar* toolbar = [NSToolbar new];
			toolbar.items = [NSMutableArray array];
			controller.window.toolbar = toolbar;
			NSCAssert(![[controller toolbarDefaultItemIdentifiers:toolbar] containsObject:@"RecordAudioNote"], @"Disabled AI must omit Dictate from initial toolbar");
			for (NSString* identifier in [controller toolbarDefaultItemIdentifiers:toolbar]) {
				[toolbar insertItemWithItemIdentifier:identifier atIndex:toolbar.items.count];
			}
			for (NSInteger i = 0; i < 3; i++) {
				uses_ai = YES;
				NSCAssert([[controller toolbarDefaultItemIdentifiers:toolbar] containsObject:@"RecordAudioNote"], @"Enabled AI must include Dictate in initial toolbar");
				[controller updateToolbarForSidebarSelection];
				[controller updateToolbarForSidebarSelection];
				NSArray* identifiers = [toolbar.items valueForKey:@"itemIdentifier"];
				NSCAssert(([identifiers isEqual:@[ @"ProfileBox", @"FlexibleSpace", @"RecordAudioNote", @"NewNote", @"NewPost" ]]), @"Enabling AI must insert Dictate before New Note without duplicates");
				uses_ai = NO;
				[controller updateToolbarForSidebarSelection];
				identifiers = [toolbar.items valueForKey:@"itemIdentifier"];
				NSCAssert(([identifiers isEqual:@[ @"ProfileBox", @"FlexibleSpace", @"NewNote", @"NewPost" ]]), @"Disabling AI must remove only Dictate");
			}
			uses_ai = YES;
			controller.selectedTimeline = kSelectionUploads;
			[controller updateToolbarForSidebarSelection];
			NSCAssert(([[toolbar.items valueForKey:@"itemIdentifier"] isEqual:@[ @"ProfileBox", @"FlexibleSpace", @"UploadButton", @"NewPost" ]]), @"Uploads must retain its existing contextual button");
			NSLog(@"Dictate toolbar AI gating and ordering checks passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-dictate-toolbar-') do |directory|
	path = File.join(directory, 'toolbar.m')
	binary = File.join(directory, 'toolbar')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Toolbar tests failed' unless system(binary)
end
