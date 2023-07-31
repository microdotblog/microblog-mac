//
//  MBHighlightsTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 7/26/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightsTableView.h"

#import "RFAllPostsController.h"
#import "RFConstants.h"

@implementation MBHighlightsTableView

- (void) mouseDown:(NSEvent *)event
{
	[super mouseDown:event];

	// right-click isn't working when we push a controller in our nav stack
	// so we'll manually handle control-click for now (not great)
	if ((event.modifierFlags & NSEventModifierFlagControl) == NSEventModifierFlagControl) {
		[NSMenu popUpContextMenu:self.menu withEvent:event forView:self];
	}
}

- (void) drawContextMenuHighlightForRow:(NSInteger)row
{
	// override to avoid the focus highlight rectangle
}
	
- (void) keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@"\r"]) {
		if ([self.delegate respondsToSelector:@selector(openRow:)]) {
			[self.delegate performSelector:@selector(openRow:) withObject:nil];
		}
	}
	else {
		[super keyDown:event];
	}
}

- (void) willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	NSInteger row = [self clickedRow];
	if (row >= 0) {
		NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:row];
		[self selectRowIndexes:index_set byExtendingSelection:NO];
	}
}

- (void) scrollWheel:(NSEvent *)event
{
	CGFloat threshold_x = 70;
	CGFloat allowed_y = 10;
	if ((event.scrollingDeltaX > threshold_x) && (event.scrollingDeltaY < allowed_y)) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
	}
	else {
		[super scrollWheel:event];
	}
}

@end
