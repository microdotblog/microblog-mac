//
//  RFHeaderBackgroundView.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFHeaderBackgroundView.h"

@implementation RFHeaderBackgroundView

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	NSRect r = [self bounds];
	[[NSColor colorWithCalibratedWhite:0.973 alpha:1.000] set];
	NSRectFill (r);
}

@end
