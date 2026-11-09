//
//  MBMoviesTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 11/2/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMoviesTableView.h"

#import "MBResponderExtras.h"

@implementation MBMoviesTableView

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
	else if ([event keyCode] == 123) { // left arrow
		if ([self.delegate respondsToSelector:@selector(moveLeft)]) {
			[self.delegate performSelector:@selector(moveLeft)];
		}
	}
	else if ([event keyCode] == 124) { // right arrow
		if ([self.delegate respondsToSelector:@selector(moveRight)]) {
			[self.delegate performSelector:@selector(moveRight)];
		}
	}
	else {
		[super keyDown:event];
	}
}

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger row = [self rowAtPoint:point];
	if (row < 0) {
		return nil;
	}

	// Select before AppKit updates the menu so validation uses the clicked movie.
	[self.window makeFirstResponder:self];
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	return [super menuForEvent:event];
}

- (BOOL) validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event
{
	// Keep context clicks on the table, including clicks over row controls.
	if (event.type == NSEventTypeRightMouseDown || (event.type == NSEventTypeLeftMouseDown && (event.modifierFlags & NSEventModifierFlagControl))) {
		return NO;
	}
	
	// Allow buttons on the first click; use normal routing for labels and images.
	if ([responder isKindOfClass:[NSButton class]]) {
		return YES;
	}
	return [super validateProposedFirstResponder:responder forEvent:event];
}

@end
