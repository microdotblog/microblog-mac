//
//  MBTimelineBackgroundView.m
//  Micro.blog
//
//  Created by Manton Reece on 7/29/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBTimelineBackgroundView.h"

@implementation MBTimelineBackgroundView

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	[[NSColor colorNamed:@"color_timeline_background"] set];
	NSRectFill (dirtyRect);
}

@end
