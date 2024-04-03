//
//  MBLogCell.m
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBLogCell.h"

#import "MBLog.h"

@implementation MBLogCell

- (void) setupWithLog:(MBLog *)log
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[NSLocale autoupdatingCurrentLocale]];

	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];

	self.dateField.stringValue = [formatter stringFromDate:log.date];
	self.messageField.stringValue = log.message;
}

@end
