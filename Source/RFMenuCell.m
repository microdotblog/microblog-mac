//
//  RFMenuCell.m
//  Snippets
//
//  Created by Manton Reece on 10/3/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMenuCell.h"

#import "NSAppearance+Extras.h"

@implementation RFMenuCell

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	if ([NSAppearance rf_isDarkMode]) {
		if (@available(macOS 10.14, *)) {
			[[NSColor selectedContentBackgroundColor] set];
		}
		else {
			[[NSColor colorWithWhite:0.0 alpha:1.0] set];
		}
	}
	else {
		[[NSColor colorWithWhite:0.9 alpha:1.0] set];
	}

//	NSRectFill (self.bounds);
    NSRect r = NSInsetRect (self.bounds, 5, 0);
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:5 yRadius:5];
    [path fill];
}

//- (NSBackgroundStyle) interiorBackgroundStyle
//{
//	return NSBackgroundStyleNormal;
//}

@end
