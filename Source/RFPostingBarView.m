//
//  RFPostingBarView.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFPostingBarView.h"

@implementation RFPostingBarView

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	NSRect r = [self bounds];
	r = NSInsetRect (r, -1, 0);
	[[NSColor lightGrayColor] set];
	NSFrameRect (r);
}

@end
