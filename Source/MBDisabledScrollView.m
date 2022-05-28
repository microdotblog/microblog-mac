//
//  MBDisabledScrollView.m
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBDisabledScrollView.h"

@implementation MBDisabledScrollView

- (BOOL) hasVerticalScroller
{
	return NO;
}

- (BOOL) hasHorizontalScroller
{
	return NO;
}

- (void) scrollWheel:(NSEvent *)event
{
	[self.superview scrollWheel:event];
}

@end
