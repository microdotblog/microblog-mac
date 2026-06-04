//
//  MBCategoriesTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBCategoriesTableView.h"

@implementation MBCategoriesTableView

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
	else if ((event.modifierFlags & NSEventModifierFlagCommand) && [[event charactersIgnoringModifiers] isEqualToString:@"\177"]) {
		if ([self.delegate respondsToSelector:@selector(delete:)]) {
			[self.delegate performSelector:@selector(delete:) withObject:nil];
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

@end
