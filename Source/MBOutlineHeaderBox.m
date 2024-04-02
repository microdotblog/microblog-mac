//
//  MBOutlineHeaderBox.m
//  Micro.blog
//
//  Created by Manton Reece on 4/2/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBOutlineHeaderBox.h"

@implementation MBOutlineHeaderBox

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	NSRect r = [self bounds];

	[self.fillColor set];
	NSRectFill (r);

	NSBezierPath *path = [NSBezierPath bezierPath];
	
	// line across the top
	[path moveToPoint:NSMakePoint(r.origin.x, r.origin.y + r.size.height)];
	[path lineToPoint:NSMakePoint(r.origin.x + r.size.width, r.origin.y + r.size.height)];

	// line across the bottom
	[path moveToPoint:NSMakePoint(r.origin.x, r.origin.y)];
	[path lineToPoint:NSMakePoint(r.origin.x + r.size.width, r.origin.y)];

	[self.borderColor set];
	[path setLineWidth:self.borderWidth];
	[path stroke];
}

@end
