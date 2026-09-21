#import "MBNotesTextView.h"
#import "MBNotesController.h"

@implementation MBNotesTextView

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
