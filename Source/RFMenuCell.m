//
//  RFMenuCell.m
//  Snippets
//
//  Created by Manton Reece on 10/3/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMenuCell.h"

#import "RFConstants.h"

@implementation RFMenuCell

- (void) awakeFromNib
{
	self.titleField.drawsBackground = NO;
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidStartLoading:) name:kTimelineDidStartLoading object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timelineDidStopLoading:) name:kTimelineDidStopLoading object:nil];
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
