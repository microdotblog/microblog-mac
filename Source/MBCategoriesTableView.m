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

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	[self selectRowForMenuEvent:event];
	return [super menuForEvent:event];
}

- (void) rightMouseDown:(NSEvent *)event
{
	if ([self selectRowForMenuEvent:event] && self.menu != nil) {
		[NSMenu popUpContextMenu:self.menu withEvent:event forView:self];
	}
	else {
		[super rightMouseDown:event];
	}
}

- (void) mouseDown:(NSEvent *)event
{
	if ((event.modifierFlags & NSEventModifierFlagControl) && [self selectRowForMenuEvent:event] && self.menu != nil) {
		[NSMenu popUpContextMenu:self.menu withEvent:event forView:self];
	}
	else {
		[super mouseDown:event];
	}
}

- (BOOL) selectRowForMenuEvent:(NSEvent *)event
{
	NSInteger row = [self rowForMenuEvent:event];
	if (row < 0) {
		return NO;
	}

	NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:row];
	[self selectRowIndexes:index_set byExtendingSelection:NO];
	return YES;
}

- (NSInteger) rowForMenuEvent:(NSEvent *)event
{
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger row = [self rowAtPoint:point];
	if (row >= 0) {
		return row;
	}

	if (self.numberOfRows > 0) {
		NSRect first_row_rect = NSInsetRect([self rectOfRow:0], 0.0, -3.0);
		if (NSPointInRect(point, first_row_rect)) {
			return 0;
		}
	}

	return -1;
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
