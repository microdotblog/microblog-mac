//
//  MBSplitView.m
//  Micro.blog
//
//  Created by Manton Reece on 5/9/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBSplitView.h"

#import "NSAppearance+Extras.h"
#import "RFConstants.h"

@implementation MBSplitView

- (void) awakeFromNib
{
	[super awakeFromNib];
	
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeAppearanceDidChangeNotification:) name:kDarkModeAppearanceDidChangeNotification object:nil];
}

- (NSColor *) dividerColor
{
	if ([NSAppearance rf_isDarkMode]) {
		return [NSColor colorWithRed:0.22 green:0.24 blue:0.26 alpha:1.0];
	}
	else {
		return [NSColor colorWithWhite:0.90 alpha:1.0];
	}
}

- (void) darkModeAppearanceDidChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
}

- (void) drawDividerInRect:(NSRect)rect
{
	[[self dividerColor] set];
	NSRectFill (rect);
}

@end
