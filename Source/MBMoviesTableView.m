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
