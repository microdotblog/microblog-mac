//
//  MBCollectionsTable.m
//  Micro.blog
//
//  Created by Manton Reece on 12/12/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBCollectionsTable.h"

#import "RFAllPostsController.h"

@implementation MBCollectionsTable

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

@end
