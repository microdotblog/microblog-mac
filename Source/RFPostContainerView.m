//
//  RFPostContainerView.m
//  Snippets
//
//  Created by Manton Reece on 10/26/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPostContainerView.h"

#import "NSAppearance+Extras.h"

@implementation RFPostContainerView

- (void) awakeFromNib
{
//	self.view.layer.masksToBounds = YES;
//	self.view.layer.cornerRadius = 10.0;

	if ([NSAppearance rf_isDarkMode]) {
		self.layer.backgroundColor = [NSColor textBackgroundColor].CGColor;
	}
	else {
		self.layer.backgroundColor = [NSColor whiteColor].CGColor;
	}
}

- (void) mouseDown:(NSEvent *)event
{
	// don't let clicks fall through to timeline underneath
}

@end
