//
//  MBBookshelvesTableView.m
//  Micro.blog
//
//  Created by Manton Reece on 5/27/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBookshelvesTableView.h"

#import "RFAllPostsController.h"

@implementation MBBookshelvesTableView

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
