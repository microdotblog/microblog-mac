//
//  WebView+Swipe.m
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "WebView+Swipe.h"

#import "RFConstants.h"

@implementation WebView (Swipe)

- (BOOL) wantsScrollEventsForSwipeTrackingOnAxis:(NSEventGestureAxis)axis
{
	if (axis == NSEventGestureAxisHorizontal) {
		return YES;
	}
	else {
		return NO;
	}
}

- (void) scrollWheel:(NSEvent *)event
{
	if (event.scrollingDeltaX > 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
	}
}

@end
