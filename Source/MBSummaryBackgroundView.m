//
//  MBSummaryBackgroundView.m
//  Micro.blog
//
//  Created by Manton Reece on 3/4/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBSummaryBackgroundView.h"

@implementation MBSummaryBackgroundView

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	NSRect r = self.bounds;
	CGFloat corner = 5;

	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:corner yRadius:corner];

	[[NSColor colorNamed:@"color_summary_background"] setFill];
	[path fill];
}

@end
