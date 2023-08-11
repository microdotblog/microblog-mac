//
//  MBTagsTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 8/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBTagsTableView.h"

#import "RFAllPostsController.h"

@implementation MBTagsTableView

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

- (BOOL) becomeFirstResponder
{
	[super becomeFirstResponder];
	
	// select first tag
	NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:0];
	[self selectRowIndexes:indexes byExtendingSelection:NO];
	
	return YES;
}

@end
