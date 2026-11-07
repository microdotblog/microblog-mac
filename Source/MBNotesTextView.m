#import "MBNotesTextView.h"
#import "MBNotesController.h"

@implementation MBNotesTextView

- (NSArray *) readablePasteboardTypes
{
	return @[ NSPasteboardTypeString ];
}

- (NSArray *) acceptableDragTypes
{
	return self.readablePasteboardTypes;
}

- (BOOL) acceptsTextFromPasteboard:(NSPasteboard *)pasteboard
{
	return [pasteboard.types containsObject:NSPasteboardTypeString]
		&& ![pasteboard.types containsObject:NSPasteboardTypeFileURL]
		&& [pasteboard availableTypeFromArray:[NSFilePromiseReceiver readableDraggedTypes]] == nil
		&& [pasteboard availableTypeFromArray:[NSImage imageTypes]] == nil;
}

- (void) paste:(id)sender
{
	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	if (self.isEditable && [self acceptsTextFromPasteboard:pasteboard]) {
		NSString* text = [pasteboard stringForType:NSPasteboardTypeString];
		if (text != nil) {
			[self insertText:text replacementRange:self.selectedRange];
		}
	}
}

- (BOOL) readSelectionFromPasteboard:(NSPasteboard *)pasteboard type:(NSPasteboardType)type
{
	if (![type isEqualToString:NSPasteboardTypeString] || ![self acceptsTextFromPasteboard:pasteboard]) {
		return NO;
	}
	return [super readSelectionFromPasteboard:pasteboard type:type];
}

- (NSDragOperation) dragOperationForDraggingInfo:(id<NSDraggingInfo>)dragInfo type:(NSPasteboardType)type
{
	if (![self acceptsTextFromPasteboard:dragInfo.draggingPasteboard]) {
		return NSDragOperationNone;
	}
	return [super dragOperationForDraggingInfo:dragInfo type:type];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if ((item.action == @selector(performFindPanelAction:)) && (item.tag == NSTextFinderActionShowFindInterface) && [self.delegate respondsToSelector:@selector(focusSearch)]) {
		return YES;
	}
	return [super validateMenuItem:item];
}

- (void) performFindPanelAction:(id)sender
{
	// Command-F searches across notes, even while editing the selected note.
	if (([sender tag] == NSTextFinderActionShowFindInterface) && [self.delegate respondsToSelector:@selector(focusSearch)]) {
		[(MBNotesController *)self.delegate focusSearch];
	}
	else {
		[super performFindPanelAction:sender];
	}
}

@end
