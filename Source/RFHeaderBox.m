//
//  RFHeaderBox.m
//  Snippets
//
//  Created by Manton Reece on 1/16/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFHeaderBox.h"

#import "NSAppearance+Extras.h"

@implementation RFHeaderBox

- (void) awakeFromNib
{
	if ([NSAppearance rf_isDarkMode]) {
		self.fillColor = [NSColor colorNamed:@"color_timeline_background"];
	}
	else {
		self.fillColor = [NSColor whiteColor];
	}
}

@end
