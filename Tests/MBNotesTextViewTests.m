#import <Cocoa/Cocoa.h>
#import "MBNotesTextView.h"

@interface MBNotesSearchTestDelegate : NSObject <NSTextViewDelegate>
@property (assign) NSInteger searchRequests;
@property (strong) NSSearchField* searchField;
@end

@implementation MBNotesSearchTestDelegate
- (void) focusSearch
{
	self.searchRequests++;
	[self.searchField.window makeFirstResponder:self.searchField];
}
@end

// Link with MBNotesTextView.m and Cocoa. Pass --window to test focus without opening Micro.blog.
int main(int argc, const char* argv[])
{
	@autoreleasepool {
		BOOL test_window = (argc > 1) && (strcmp(argv[1], "--window") == 0);
		if (test_window) {
			[NSApplication sharedApplication];
		}
		MBNotesTextView* editor = [[MBNotesTextView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
		NSTextView* standard_editor = [[NSTextView alloc] initWithFrame:editor.frame];
		MBNotesSearchTestDelegate* delegate = [[MBNotesSearchTestDelegate alloc] init];
		editor.delegate = delegate;
		editor.string = @"Keep this note unchanged.";
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Find…" action:@selector(performFindPanelAction:) keyEquivalent:@"f"];
		item.tag = NSTextFinderActionShowFindInterface;
		NSCAssert([editor validateMenuItem:item], @"Find must be enabled while editing a note");
		[editor performFindPanelAction:item];
		NSCAssert(delegate.searchRequests == 1, @"Find must reach Notes search");
		NSCAssert([editor.string isEqualToString:@"Keep this note unchanged."], @"Find must not edit the note");
		for (NSNumber* tag in @[ @2, @3, @7, @12 ]) {
			item.tag = tag.integerValue;
			NSCAssert([editor validateMenuItem:item] == [standard_editor validateMenuItem:item], @"Other Find commands must retain standard validation");
		}
		editor.delegate = nil;
		item.tag = NSTextFinderActionShowFindInterface;
		NSCAssert([editor validateMenuItem:item] == [standard_editor validateMenuItem:item], @"No delegate must retain standard validation");
		editor.delegate = delegate;
		if (test_window) {
			NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 250) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			delegate.searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 210, 300, 24)];
			[window.contentView addSubview:editor];
			[window.contentView addSubview:delegate.searchField];
			NSCAssert([window makeFirstResponder:editor], @"Editor must accept focus");
			[editor performFindPanelAction:item];
			NSCAssert(window.firstResponder == delegate.searchField.currentEditor, @"Find must move keyboard focus into search");
		}
		NSLog(@"Passed Notes Find routing, menu validation, and text preservation checks%@.", test_window ? @", including search-field focus" : @"");
	}
	return 0;
}
