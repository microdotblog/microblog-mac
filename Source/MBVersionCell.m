//
//  MBVersionCell.m
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVersionCell.h"

#import "MBVersion.h"

@implementation MBVersionCell

- (void) setupWithVersion:(MBVersion *)version
{
	NSString* s = version.text;
	if (s.length > 300) {
		s = [s substringToIndex:300];
		s = [s stringByAppendingString:@"..."];
	}
	self.textField.stringValue = s;
	
	NSString* date_s = [NSDateFormatter localizedStringFromDate:version.createdAt dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
	if (date_s) {
		self.dateField.stringValue = date_s;
	}
}

@end
