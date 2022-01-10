//
//  MBRestoreCursorView.m
//  Micro.blog
//
//  Created by Manton Reece on 1/10/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBRestoreCursorView.h"

@implementation MBRestoreCursorView

- (void) awakeFromNib
{
	NSTrackingArea* area = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
	[self addTrackingArea:area];
}

- (void) cursorUpdate:(NSEvent *)event
{
	[super cursorUpdate:event];
	
	[[NSCursor arrowCursor] set];
}

@end
