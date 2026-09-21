#import <Cocoa/Cocoa.h>
#import "MBLinkHoverBubble.h"

int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 500)];
		MBLinkHoverBubble* bubble = [[MBLinkHoverBubble alloc] initWithFrame:NSZeroRect];
		[container addSubview:bubble];
		[NSLayoutConstraint activateConstraints:@[
			[bubble.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14],
			[bubble.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14],
			[bubble.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-14],
			[bubble.widthAnchor constraintLessThanOrEqualToConstant:450]
		]];
		NSCAssert(bubble.hidden, @"Initially hidden");
		bubble.hidden = NO;
		bubble.textField.stringValue = @"https://micro.blog/";
		[container layoutSubtreeIfNeeded];
		CGFloat short_width = bubble.frame.size.width;
		NSCAssert(short_width > 24 && short_width < 450, @"Short URLs fit their content");
		NSCAssert([bubble hitTest:NSMakePoint(20, 20)] == nil, @"Pill must not intercept clicks");
		bubble.textField.stringValue = [@"https://example.com/" stringByAppendingString:[@"long-path/" stringByPaddingToLength:500 withString:@"long-path/" startingAtIndex:0]];
		[container layoutSubtreeIfNeeded];
		NSCAssert(bubble.frame.size.width <= 450, @"Long URLs have a maximum width");
		NSCAssert(bubble.textField.lineBreakMode == NSLineBreakByTruncatingMiddle, @"Keep both ends of the URL visible");
		container.frame = NSMakeRect(0, 0, 280, 500);
		[container layoutSubtreeIfNeeded];
		NSCAssert(NSMaxX(bubble.frame) <= 266, @"Fit narrow windows");
		NSCAssert(bubble.frame.size.height > 20, @"Label retains its height");
		NSLog(@"Link hover bubble tests passed.");
	}
	return 0;
}
