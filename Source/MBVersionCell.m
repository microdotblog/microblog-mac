//
//  MBVersionCell.m
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVersionCell.h"

#import "MBVersion.h"

static NSInteger const kVersionTextMaxLength = 400;

@implementation MBVersionCell

- (void) setupWithVersion:(MBVersion *)version
{
	NSString* s = version.text;
	if (s.length > kVersionTextMaxLength) {
		s = [s substringToIndex:kVersionTextMaxLength];
		s = [s stringByAppendingString:@"..."];
	}
	self.textField.stringValue = s;
	
	NSString* date_s = [NSDateFormatter localizedStringFromDate:version.createdAt dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
	if (date_s) {
		self.dateField.stringValue = date_s;
	}
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	if (selected) {
		self.dateField.textColor = [NSColor colorNamed:@"color_date_text_selected"];
	}
	else {
		self.dateField.textColor = [NSColor colorNamed:@"color_date_text"];
	}
}

@end
