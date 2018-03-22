//
//  RFBlogCell.m
//  Snippets
//
//  Created by Manton Reece on 3/21/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFBlogCell.h"

@implementation RFBlogCell

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
