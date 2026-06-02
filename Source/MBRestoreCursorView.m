//
//  MBRestoreCursorView.m
//  Micro.blog
//
//  Created by Manton Reece on 1/10/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBRestoreCursorView.h"

@implementation MBRestoreCursorView

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupTrackingArea];
	}
	return self;
}

- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self setupTrackingArea];
	}
	return self;
}

- (void) awakeFromNib
{
	[super awakeFromNib];
}

- (void) setupTrackingArea
{
	NSTrackingArea* area = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
	[self addTrackingArea:area];
}

- (void) cursorUpdate:(NSEvent *)event
{
	[super cursorUpdate:event];
	
	[[NSCursor arrowCursor] set];
}

@end
