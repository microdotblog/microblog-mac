#import "MBSeparatorView.h"

@implementation MBSeparatorView

- (NSSize) intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, 1);
}

- (void) drawRect:(NSRect)dirtyRect
{
	[[NSColor separatorColor] setFill];
	NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
}

@end
