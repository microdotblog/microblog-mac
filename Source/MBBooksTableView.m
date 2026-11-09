//
//  MBBooksTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 11/10/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "MBBooksTableView.h"

#import "MBResponderExtras.h"

@implementation MBBooksTableView

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

- (NSMenu *) menuForEvent:(NSEvent *)event
{
	NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger row = [self rowAtPoint:point];
	if (row < 0) {
		return nil;
	}

	// Select before AppKit updates the menu so validation uses the clicked book.
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
