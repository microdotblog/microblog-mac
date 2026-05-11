//
//  MBSplitView.m
//  Micro.blog
//
//  Created by Manton Reece on 5/9/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBSplitView.h"

@implementation MBSplitView

- (NSColor *) dividerColor
{
	return [NSColor separatorColor];
}

- (void) drawDividerInRect:(NSRect)rect
{
	[[self dividerColor] set];
	NSRectFill (rect);
}

@end
