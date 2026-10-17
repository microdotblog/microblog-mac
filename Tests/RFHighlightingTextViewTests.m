#import <Cocoa/Cocoa.h>
#import "RFHighlightingTextView.h"

// Link with RFHighlightingTextView.m and Cocoa. No account or networking is used.
@interface RFSettings : NSObject
+ (void) addTemporaryFolder:(NSString *)path;
@end
@implementation RFSettings
+ (void) addTemporaryFolder:(NSString *)path {}
@end

@interface RFAutoCompleteCache : NSObject
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler;
@end
@implementation RFAutoCompleteCache
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler { handler(@[]); }
@end

@interface RFHighlightingTextView (ImageDropTests)
- (BOOL) insertDraggedImageHTMLFromPasteboard:(NSPasteboard *)pasteboard atIndex:(NSUInteger)insertionIndex;
@end

@interface TestImageDropEditor : RFHighlightingTextView
@property (strong) NSUndoManager* testUndoManager;
@property NSUInteger dropIndex;
@property NSPoint lastDropPoint;
@end
@implementation TestImageDropEditor
- (NSUndoManager *) undoManager { return self.testUndoManager; }
- (NSUInteger) characterIndexForInsertionAtPoint:(NSPoint)point
{
	self.lastDropPoint = point;
	return self.dropIndex;
}
@end

@interface TestImageDrag : NSObject
@property (strong) NSPasteboard* draggingPasteboard;
@property NSPoint draggingLocation;
@end
@implementation TestImageDrag
@end

static void write_items(NSPasteboard* pasteboard, NSArray* strings)
{
	[pasteboard clearContents];
	NSMutableArray* items = [NSMutableArray array];
	for (NSString* string in strings) {
		NSPasteboardItem* item = [NSPasteboardItem new];
		[item setString:string forType:NSPasteboardTypeString];
		[items addObject:item];
	}
	if (items.count > 0) {
		NSCAssert([pasteboard writeObjects:items], @"Write the same plain-text HTML as Uploads");
	}
}

int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		TestImageDropEditor* editor = [[TestImageDropEditor alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
		editor.richText = NO;
		editor.allowsUndo = YES;
		editor.testUndoManager = [NSUndoManager new];
		editor.testUndoManager.groupsByEvent = NO;
		NSPasteboard* pasteboard = [NSPasteboard pasteboardWithUniqueName];
		NSString* image = @"<img src=\"https://example.com/photo.jpg\" alt=\"A photo\">";
		write_items(pasteboard, @[image]);

		NSString* original = @"A caption 🌞";
		editor.string = original;
		editor.selectedRange = NSMakeRange(0, 4);
		editor.dropIndex = original.length;
		TestImageDrag* drag = [TestImageDrag new];
		drag.draggingPasteboard = pasteboard;
		drag.draggingLocation = NSMakePoint(30, 40);
		NSPoint expected_point = [editor convertPoint:drag.draggingLocation fromView:nil];
		__block NSInteger changes = 0;
		id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSTextDidChangeNotification object:editor queue:nil usingBlock:^(NSNotification* notification) { changes++; }];
		[editor.testUndoManager beginUndoGrouping];
		NSCAssert([editor performDragOperation:(id<NSDraggingInfo>)drag], @"Handle an image HTML drop at the end");
		[editor.testUndoManager endUndoGrouping];
		NSString* expected = [original stringByAppendingFormat:@"\n\n%@", image];
		NSCAssert([editor.string isEqualToString:expected], @"Append exactly two newlines before the unmodified tag");
		NSCAssert(NSEqualPoints(editor.lastDropPoint, expected_point), @"Convert the actual drop position into editor coordinates");
		NSCAssert(editor.selectedRange.location == expected.length && editor.selectedRange.length == 0, @"Caret follows the inserted tag, not the previous selection");
		NSCAssert(changes == 1, @"Notify the post controller about the edit");
		[editor.testUndoManager undo];
		NSCAssert([editor.string isEqualToString:original], @"One undo removes both the separator and tag");
		[editor.testUndoManager redo];
		NSCAssert([editor.string isEqualToString:expected], @"Redo restores the whole insertion");
		[[NSNotificationCenter defaultCenter] removeObserver:observer];

		for (NSString* text in @[@"", @"Caption ", @"Caption\n", @"Caption\r", @"Caption\t", @"Caption\u00a0"]) {
			editor.string = text;
			NSCAssert(![editor insertDraggedImageHTMLFromPasteboard:pasteboard atIndex:text.length], @"Empty text and existing whitespace use the normal drop path");
			NSCAssert([editor.string isEqualToString:text], @"No extra whitespace");
		}
		editor.string = @"Caption text";
		for (NSNumber* index in @[@0, @4, @(NSNotFound)]) {
			NSCAssert(![editor insertDraggedImageHTMLFromPasteboard:pasteboard atIndex:index.unsignedIntegerValue], @"Other drop positions use the normal path");
		}
		editor.editable = NO;
		NSCAssert(![editor insertDraggedImageHTMLFromPasteboard:pasteboard atIndex:editor.string.length], @"Do not edit a read-only view");
		editor.editable = YES;
		for (NSArray* strings in @[@[], @[@"ordinary text"], @[@"<video src=\"movie.mp4\"></video>"], @[image, @"ordinary text"]]) {
			write_items(pasteboard, strings);
			NSCAssert(![editor insertDraggedImageHTMLFromPasteboard:pasteboard atIndex:editor.string.length], @"Non-photo and mixed drops retain normal behavior");
		}
		NSString* second_image = @"<img src=\"https://example.com/second.png\">";
		write_items(pasteboard, @[image, second_image]);
		[editor.testUndoManager beginUndoGrouping];
		NSCAssert([editor insertDraggedImageHTMLFromPasteboard:pasteboard atIndex:editor.string.length], @"Handle all selected photos");
		[editor.testUndoManager endUndoGrouping];
		expected = [NSString stringWithFormat:@"Caption text\n\n%@\n%@", image, second_image];
		NSCAssert([editor.string isEqualToString:expected], @"Do not lose photos from a multi-item drag");
		[pasteboard releaseGlobally];
		NSLog(@"Photo HTML drop spacing, positions, multiple photos, caret, notification, and undo tests passed.");
	}
	return 0;
}
