//
//  RFMenuCell.m
//  Snippets
//
//  Created by Manton Reece on 10/3/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMenuCell.h"

@implementation RFMenuCell

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	[[NSColor colorWithWhite:0.95 alpha:1.0] set];
	NSRectFill (self.bounds);
}

- (NSBackgroundStyle) interiorBackgroundStyle
{
	return NSBackgroundStyleLight;
}

@end
