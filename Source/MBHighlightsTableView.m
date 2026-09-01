//
//  MBHighlightsTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 7/26/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightsTableView.h"

#import "RFAllPostsController.h"
#import "RFConstants.h"

static CGFloat const MBHighlightsSwipeBackThreshold = 70.0;
static CGFloat const MBHighlightsSwipeBackHorizontalDominance = 1.5;
static NSTimeInterval const MBHighlightsUnphasedGestureTimeout = 0.25;

@interface MBHighlightsTableView ()

@property (assign) CGFloat accumulatedSwipeBackDelta;
@property (assign) CGFloat accumulatedVerticalDelta;
@property (assign) BOOL isTrackingSwipeBack;
@property (assign) BOOL didTriggerSwipeBack;
@property (assign) NSTimeInterval lastUnphasedScrollTimestamp;
@property (assign) NSPoint swipeBackScrollOrigin;
@property (assign) BOOL hasSwipeBackScrollOrigin;

@end

@implementation MBHighlightsTableView

- (void) mouseDown:(NSEvent *)event
{
	[super mouseDown:event];

	// right-click isn't working when we push a controller in our nav stack
	// so we'll manually handle control-click for now (not great)
	if ((event.modifierFlags & NSEventModifierFlagControl) == NSEventModifierFlagControl) {
		[NSMenu popUpContextMenu:self.menu withEvent:event forView:self];
	}
}

- (void) drawContextMenuHighlightForRow:(NSInteger)row
{
	// override to avoid the focus highlight rectangle
}
	
- (void) keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@"\r"]) {
		if ([self.delegate respondsToSelector:@selector(openRow:)]) {
			[self.delegate performSelector:@selector(openRow:) withObject:nil];
		}
	}
	else {
		[super keyDown:event];
	}
}

- (void) willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	NSInteger row = [self clickedRow];
	if (row >= 0) {
		NSIndexSet* index_set = [NSIndexSet indexSetWithIndex:row];
		[self selectRowIndexes:index_set byExtendingSelection:NO];
	}
}

- (void) scrollWheel:(NSEvent *)event
{
	if (event.momentumPhase != NSEventPhaseNone) {
		if (self.didTriggerSwipeBack) {
			[self restoreSwipeBackScrollPosition];
			BOOL finished_momentum = ((event.momentumPhase & NSEventPhaseEnded) || (event.momentumPhase & NSEventPhaseCancelled));
			if (finished_momentum) {
				[self resetSwipeBackTracking];
			}
			return;
		}

		[super scrollWheel:event];
		return;
	}

	BOOL has_gesture_phase = (event.phase != NSEventPhaseNone);
	if (!has_gesture_phase) {
		NSTimeInterval elapsed = event.timestamp - self.lastUnphasedScrollTimestamp;
		if (!self.isTrackingSwipeBack || (elapsed > MBHighlightsUnphasedGestureTimeout)) {
			[self beginSwipeBackTracking];
		}
		self.lastUnphasedScrollTimestamp = event.timestamp;
	}
	else if ((event.phase & NSEventPhaseBegan) || (event.phase & NSEventPhaseMayBegin)) {
		[self beginSwipeBackTracking];
	}
	else if ((event.phase & NSEventPhaseChanged) && !self.isTrackingSwipeBack) {
		[self beginSwipeBackTracking];
	}

	if (self.isTrackingSwipeBack && !self.didTriggerSwipeBack) {
		self.accumulatedSwipeBackDelta += [self swipeBackDeltaForEvent:event];
		self.accumulatedVerticalDelta += fabs (event.scrollingDeltaY * [self scrollingScaleForEvent:event]);

		BOOL passed_threshold = (self.accumulatedSwipeBackDelta > MBHighlightsSwipeBackThreshold);
		BOOL is_horizontal = (self.accumulatedSwipeBackDelta > (self.accumulatedVerticalDelta * MBHighlightsSwipeBackHorizontalDominance));
		if (passed_threshold && is_horizontal) {
			self.didTriggerSwipeBack = YES;
			[self restoreSwipeBackScrollPosition];
			[[NSNotificationCenter defaultCenter] postNotificationName:kPopNavigationNotification object:self];
			[self restoreSwipeBackScrollPosition];
			return;
		}
	}

	BOOL finished_gesture = ((event.phase & NSEventPhaseEnded) || (event.phase & NSEventPhaseCancelled));
	if (self.didTriggerSwipeBack) {
		[self restoreSwipeBackScrollPosition];
		if (finished_gesture) {
			self.isTrackingSwipeBack = NO;
		}
		return;
	}

	[super scrollWheel:event];

	if (finished_gesture) {
		[self resetSwipeBackTracking];
	}
}

- (CGFloat) swipeBackDeltaForEvent:(NSEvent *)event
{
	CGFloat device_delta_x = event.scrollingDeltaX * [self scrollingScaleForEvent:event];
	if (event.isDirectionInvertedFromDevice) {
		device_delta_x *= -1.0;
	}

	// Device deltas are negative for a rightward gesture, so make Back progress positive.
	return -device_delta_x;
}

- (CGFloat) scrollingScaleForEvent:(NSEvent *)event
{
	if (event.hasPreciseScrollingDeltas) {
		return 1.0;
	}
	else {
		return MAX (self.rowHeight, 1.0);
	}
}

- (void) beginSwipeBackTracking
{
	[self resetSwipeBackTracking];
	self.isTrackingSwipeBack = YES;

	NSClipView* clip_view = self.enclosingScrollView.contentView;
	if (clip_view) {
		self.swipeBackScrollOrigin = clip_view.bounds.origin;
		self.hasSwipeBackScrollOrigin = YES;
	}
}

- (void) restoreSwipeBackScrollPosition
{
	if (self.hasSwipeBackScrollOrigin) {
		NSScrollView* scroll_view = self.enclosingScrollView;
		[scroll_view.contentView scrollToPoint:self.swipeBackScrollOrigin];
		[scroll_view reflectScrolledClipView:scroll_view.contentView];
	}
}

- (void) resetSwipeBackTracking
{
	self.accumulatedSwipeBackDelta = 0.0;
	self.accumulatedVerticalDelta = 0.0;
	self.isTrackingSwipeBack = NO;
	self.didTriggerSwipeBack = NO;
	self.lastUnphasedScrollTimestamp = 0.0;
	self.hasSwipeBackScrollOrigin = NO;
}

@end
