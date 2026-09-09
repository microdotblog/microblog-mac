#import "MBLinksTableView.h"

@implementation MBLinksTableView

- (void) drawContextMenuHighlightForRow:(NSInteger)row
{
	// Use the selected row background instead of a context-menu outline.
}

- (void) willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	NSInteger row = self.clickedRow;
	if (row >= 0) {
		[self.window makeFirstResponder:self];
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	}
}

@end
