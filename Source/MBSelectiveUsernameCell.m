//
//  MBSelectiveUsernameCell.m
//  Micro.blog
//
//  Created by Manton Reece on 6/16/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBSelectiveUsernameCell.h"

@implementation MBSelectiveUsernameCell

- (void) viewDidLoad
{
	[super viewDidLoad];

	self.view.wantsLayer = YES;
	self.view.layer.cornerRadius = 5;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];

	NSColor* c = selected ? [NSColor lightGrayColor] : [NSColor whiteColor];
	self.view.layer.backgroundColor = c.CGColor;
}

@end
