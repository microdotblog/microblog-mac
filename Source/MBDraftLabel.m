//
//  MBDraftLabel.m
//  Micro.blog
//
//  Created by Manton Reece on 12/5/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBDraftLabel.h"

@implementation MBDraftLabel

- (void) drawRect:(NSRect)dirtyRect
{
	NSRect r = [self bounds];
	NSColor* c = self.bubbleColor ?: [[NSColor lightGrayColor] colorWithAlphaComponent:0.5];
	[c set];
	
	CGFloat radius = 5.0;
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
	[path fill];
	
	[super drawRect:dirtyRect];
}

- (void) setBubbleColor:(NSColor *)bubbleColor
{
	_bubbleColor = bubbleColor;
	self.needsDisplay = YES;
}

@end
