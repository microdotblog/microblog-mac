//
//  RFPostTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 11/10/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFPostTableView.h"

#import "RFAllPostsController.h"

@implementation RFPostTableView

- (void) drawBackgroundInClipRect:(NSRect)clipRect
{
	// override the alternating rows NSTableView draws outside actual rows
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

@end
