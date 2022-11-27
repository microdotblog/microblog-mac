//
//  RFMenuCell.m
//  Snippets
//
//  Created by Manton Reece on 10/3/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMenuCell.h"

#import "NSAppearance+Extras.h"
#import "RFConstants.h"

@implementation RFMenuCell

- (void) awakeFromNib
{
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidStartLoading:) name:kTimelineDidStartLoading object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidStopLoading:) name:kTimelineDidStopLoading object:nil];
}

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

- (void) timelineDidStartLoading:(NSNotification *)notification
{
	if ([[notification.userInfo objectForKey:kTimelineSidebarRowKey] integerValue] == self.sidebarRow) {
		[self.progressSpinner startAnimation:nil];
	}
}

- (void) timelineDidStopLoading:(NSNotification *)notification
{
	[self.progressSpinner stopAnimation:nil];
}

//- (NSBackgroundStyle) interiorBackgroundStyle
//{
//	return NSBackgroundStyleNormal;
//}

@end
