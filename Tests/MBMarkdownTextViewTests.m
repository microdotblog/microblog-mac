#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "MBNotesTextView.h"
#import "RFHighlightingTextView.h"
#import "RFHighlightingTextStorage.h"
#import "RFConstants.h"

// Link the two editors, MBMarkdownTextView.m, and RFHighlightingTextStorage.m.
// Pass the built app bundle to use its syntax colors. No account or networking is used.
@interface RFSettings : NSObject
+ (void) addTemporaryFolder:(NSString *)path;
@end
@implementation RFSettings
+ (void) addTemporaryFolder:(NSString *)path {}
@end

static NSInteger autocomplete_requests;
@interface RFAutoCompleteCache : NSObject
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler;
@end
@implementation RFAutoCompleteCache
+ (void) findAutoCompleteFor:(NSString *)string completion:(void (^)(NSArray*))handler
{
	autocomplete_requests++;
	handler(@[]);
}
@end

static NSBundle* app_bundle;
@interface NSColor (MarkdownTests)
+ (NSColor *) markdownTestColorNamed:(NSString *)name;
@end
@implementation NSColor (MarkdownTests)
+ (NSColor *) markdownTestColorNamed:(NSString *)name
{
	return [self markdownTestColorNamed:name] ?: [self colorNamed:name bundle:app_bundle];
}
@end

static NSPasteboard* test_pasteboard;
@interface NSPasteboard (MarkdownTests)
+ (NSPasteboard *) markdownTestPasteboard;
@end
@implementation NSPasteboard (MarkdownTests)
+ (NSPasteboard *) markdownTestPasteboard { return test_pasteboard; }
@end

@interface NotesEditingDelegate : NSObject <NSTextViewDelegate>
@property (strong) NSUndoManager* undoManager;
@property (copy) NSString* savedText;
@property NSInteger changes;
@end
@implementation NotesEditingDelegate
- (NSUndoManager *) undoManagerForTextView:(NSTextView *)textView { return self.undoManager; }
- (void) textDidChange:(NSNotification *)notification
{
	self.savedText = [(NSTextView *)notification.object string];
	self.changes++;
}
@end

@interface NotesImageDrag : NSObject
@property (strong) NSPasteboard* draggingPasteboard;
@end
@implementation NotesImageDrag @end

@interface MBNotesTextView (MarkdownTests)
- (BOOL) acceptsTextFromPasteboard:(NSPasteboard *)pasteboard;
@end

static NSFont* font_at(NSTextView* editor, NSString* word)
{
	NSRange range = [editor.string rangeOfString:word];
	NSCAssert(range.location != NSNotFound, @"Find the expected Markdown token");
	return [editor.textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
}

int main(int argc, const char* argv[])
{
	@autoreleasepool {
		NSCAssert(argc == 2, @"Pass the built Micro.blog app bundle");
		app_bundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
		NSCAssert(app_bundle != nil, @"Load real syntax color assets");
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
		Method colors = class_getClassMethod(NSColor.class, @selector(colorNamed:));
		Method test_colors = class_getClassMethod(NSColor.class, @selector(markdownTestColorNamed:));
		method_exchangeImplementations(colors, test_colors);

		MBNotesTextView* notes = [[MBNotesTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 300)];
		RFHighlightingTextView* post = [[RFHighlightingTextView alloc] initWithFrame:notes.frame];
		NSString* markdown = @"# Heading\n\nSome **bold** and _italic_ and [a link](https://micro.blog).\n\n> Quoted text\n\n<em>HTML</em>";
		notes.string = markdown;
		[notes setupMarkdownWithFontSize:14];
		[post setupMarkdownWithFontSize:kDefaultFontSize];
		post.string = markdown;
		NSCAssert([notes.textStorage isKindOfClass:RFHighlightingTextStorage.class] && [post.textStorage isKindOfClass:RFHighlightingTextStorage.class], @"Both editors use the same highlighter");
		NSCAssert([notes.string isEqualToString:markdown], @"Installing highlighting preserves existing plain Markdown");
		NSCAssert(font_at(notes, @"Some").pointSize == 14 && font_at(post, @"Some").pointSize == 16, @"Keep Notes and post font sizes");
		for (NSString* word in @[@"Heading", @"bold"]) {
			NSCAssert(([NSFontManager.sharedFontManager traitsOfFont:font_at(notes, word)] & NSFontBoldTrait) != 0, @"Bold Markdown and headings render bold");
		}
		NSCAssert(([NSFontManager.sharedFontManager traitsOfFont:font_at(notes, @"italic")] & NSFontItalicTrait) != 0, @"Italic Markdown renders italic");
		for (NSString* word in @[@"Heading", @"a link", @"https://micro.blog", @"Quoted", @"<em>"]) {
			NSUInteger index = [markdown rangeOfString:word].location;
			NSColor* note_color = [notes.textStorage attribute:NSForegroundColorAttributeName atIndex:index effectiveRange:NULL];
			NSColor* post_color = [post.textStorage attribute:NSForegroundColorAttributeName atIndex:index effectiveRange:NULL];
			NSCAssert([note_color isEqual:post_color], @"Share all syntax colors with the post editor");
		}

		NotesEditingDelegate* delegate = [NotesEditingDelegate new];
		delegate.undoManager = [NSUndoManager new];
		delegate.undoManager.groupsByEvent = NO;
		notes.delegate = delegate;
		notes.allowsUndo = YES;
		notes.string = @"Before _word_ after";
		NSUInteger index = [notes.string rangeOfString:@"word"].location;
		[delegate.undoManager beginUndoGrouping];
		[notes insertText:@"✨" replacementRange:NSMakeRange(index, 0)];
		[delegate.undoManager endUndoGrouping];
		NSCAssert([notes.string isEqualToString:@"Before _✨word_ after"] && notes.selectedRange.location == index + @"✨".length, @"Highlighting preserves the caret during edits in the middle");
		NSCAssert(delegate.changes == 1 && [delegate.savedText isEqualToString:notes.string], @"A text edit produces one plain-text sync/preview notification");
		[delegate.undoManager undo];
		NSCAssert([notes.string isEqualToString:@"Before _word_ after"], @"Undo restores Markdown");
		[delegate.undoManager redo];
		NSCAssert([notes.string isEqualToString:@"Before _✨word_ after"], @"Redo restores the edit");
		[delegate.undoManager beginUndoGrouping];
		[notes insertText:@"@" replacementRange:NSMakeRange(notes.string.length, 0)];
		[delegate.undoManager endUndoGrouping];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
		NSCAssert(autocomplete_requests == 0, @"Notes never invokes post username completion");

		test_pasteboard = [NSPasteboard pasteboardWithUniqueName];
		__block NSInteger attachments = 0;
		id observer = [NSNotificationCenter.defaultCenter addObserverForName:kAttachFilesNotification object:notes queue:nil usingBlock:^(NSNotification* notification) { attachments++; }];
		Method pasteboard = class_getClassMethod(NSPasteboard.class, @selector(generalPasteboard));
		Method isolated = class_getClassMethod(NSPasteboard.class, @selector(markdownTestPasteboard));
		method_exchangeImplementations(pasteboard, isolated);
		@try {
			NSString* pasted_text = @"Plain **Markdown**";
			NSAttributedString* rich_text = [[NSAttributedString alloc] initWithString:pasted_text attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:60]}];
			NSData* rtf = [rich_text RTFFromRange:NSMakeRange(0, rich_text.length) documentAttributes:@{}];
			[test_pasteboard declareTypes:@[NSPasteboardTypeString, NSPasteboardTypeRTF] owner:nil];
			[test_pasteboard setString:pasted_text forType:NSPasteboardTypeString];
			[test_pasteboard setData:rtf forType:NSPasteboardTypeRTF];
			NSCAssert([notes acceptsTextFromPasteboard:test_pasteboard], @"A clipboard with plain text and RTF must be accepted");
			notes.selectedRange = NSMakeRange(0, notes.string.length);
			[delegate.undoManager beginUndoGrouping];
			[notes paste:nil];
			[delegate.undoManager endUndoGrouping];
			NSCAssert([notes.string isEqualToString:pasted_text] && font_at(notes, @"Plain").pointSize == 14, @"Paste retains Markdown but discards external rich formatting: text=%@, image type=%@, font=%@", notes.string, [test_pasteboard availableTypeFromArray:NSImage.imageTypes], notes.font);
			NSCAssert(![notes readSelectionFromPasteboard:test_pasteboard type:NSPasteboardTypeRTF], @"Other rich-text paste paths cannot import formatting");

			NSBitmapImageRep* image = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1 pixelsHigh:1 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
			NSData* png = [image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
			NotesImageDrag* drag = [NotesImageDrag new];
			drag.draggingPasteboard = test_pasteboard;
			NSArray* unsupported = @[
				@{NSPasteboardTypePNG: png},
				@{NSPasteboardTypePNG: png, NSPasteboardTypeString: @"Image URL"},
				@{NSPasteboardTypeFileURL: @"file:///tmp/photo.png", NSPasteboardTypeString: @"photo.png"},
				@{NSFilePromiseReceiver.readableDraggedTypes.firstObject: @"public.png", NSPasteboardTypeString: @"Promised image"}
			];
			for (NSDictionary* representations in unsupported) {
				[test_pasteboard declareTypes:representations.allKeys owner:nil];
				for (NSString* type in representations) {
					id value = representations[type];
					if ([value isKindOfClass:NSData.class]) [test_pasteboard setData:value forType:type];
					else [test_pasteboard setString:value forType:type];
				}
				[notes paste:nil];
				NSCAssert(![notes readSelectionFromPasteboard:test_pasteboard type:NSPasteboardTypeString], @"Media cannot be inserted through a plain-text fallback");
				NSCAssert([notes dragOperationForDraggingInfo:(id<NSDraggingInfo>)drag type:NSPasteboardTypeString] == NSDragOperationNone, @"Reject image, file, and promised-file drags");
				NSCAssert([notes.string isEqualToString:pasted_text] && attachments == 0, @"Unsupported media never alters the note or attaches to a post");
			}
			[test_pasteboard declareTypes:@[NSPasteboardTypeString] owner:nil];
			[test_pasteboard setString:@" ordinary text" forType:NSPasteboardTypeString];
			notes.selectedRange = NSMakeRange(notes.string.length, 0);
			[delegate.undoManager beginUndoGrouping];
			NSCAssert([notes readSelectionFromPasteboard:test_pasteboard type:NSPasteboardTypeString], @"Ordinary text drops remain supported");
			[delegate.undoManager endUndoGrouping];
		}
		@finally {
			method_exchangeImplementations(pasteboard, isolated);
			[NSNotificationCenter.defaultCenter removeObserver:observer];
			[test_pasteboard releaseGlobally];
			method_exchangeImplementations(colors, test_colors);
		}
		NSLog(@"Shared Markdown editor checks passed: syntax styles, font sizes, caret, undo/redo, edit notifications, plain-text paste/drop, no attachments, and no username completion.");
	}
	return 0;
}
