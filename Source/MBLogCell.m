//
//  MBLogCell.m
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBLogCell.h"

#import "MBLog.h"

static NSString* const kPublishLogPhrase = @"Publish: Done";

@implementation MBLogCell

- (void) setupWithLog:(MBLog *)log
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[NSLocale autoupdatingCurrentLocale]];

	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];

	self.dateField.stringValue = [formatter stringFromDate:log.date];
	self.messageField.stringValue = log.message;

	if ([log.message containsString:kPublishLogPhrase]) {
		// reset as green text
		self.dateField.attributedStringValue = [self greenStringForText:self.dateField.stringValue];
		self.messageField.attributedStringValue = [self greenStringForText:self.messageField.stringValue];
	}
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	// when selected, reset the color if needed
	if ([self.messageField.stringValue containsString:kPublishLogPhrase]) {
		self.dateField.attributedStringValue = [self greenStringForText:self.dateField.stringValue];
		self.messageField.attributedStringValue = [self greenStringForText:self.messageField.stringValue];
	}
}

- (NSAttributedString *) greenStringForText:(NSString *)text
{
	NSColor* color;
	if (self.isSelected) {
		color = [NSColor colorNamed:@"color_logs_publish_selected"];
	}
	else {
		color = [NSColor colorNamed:@"color_logs_publish"];
	}
	
	NSFont* bold_font = [NSFont boldSystemFontOfSize:self.messageField.font.pointSize];
	NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:text];

	[attr addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attr.length)];
	[attr addAttribute:NSFontAttributeName value:bold_font range:NSMakeRange(0, attr.length)];
	
	return attr;
}

@end
