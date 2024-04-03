//
//  MBBooksTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 11/10/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "MBBooksTableView.h"

#import "RFAllPostsController.h"

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

- (void) willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	NSInteger row = [self clickedRow];
	if (row >= 0) {
		NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:row];
		[self selectRowIndexes:index_set byExtendingSelection:NO];
	}
}

- (BOOL) validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event
{
	// for right-clicks, we let the table handle it
	if (([event modifierFlags] & NSEventModifierFlagControl) || ([event type] == NSEventTypeRightMouseDown)) {
		return [super validateProposedFirstResponder:responder forEvent:event];
	}
	
	// allow clicks in buttons no matter the selection style
	return YES;
}

@end
