//
//  NSLocale+Format.m
//  Micro.blog
//
//  Created by Manton Reece on 8/13/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "NSLocale+Format.h"

static NSString * MBNormalizeDateSeparator(NSString* raw)
{
	if (!raw) {
		return @"";
	}
	
	// trim a wide set of unicode spaces
	NSMutableCharacterSet *spaces = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
	const unsigned int extraSpaces[] = { 0x00A0, 0x202F, 0x2009, 0x2007, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2008, 0x200A, 0x205F, 0x3000 };
	for (int i = 0; i < sizeof(extraSpaces)/sizeof(extraSpaces[0]); i++) {
		[spaces addCharactersInRange:NSMakeRange(extraSpaces[i], 1)];
	}
	NSString* trimmed = [raw stringByTrimmingCharactersInSet:spaces];

	// strip invisible controls and soft hyphen
	const unsigned int invis[] = { 0x200B, 0x200C, 0x200D, 0x2060, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069, 0x00AD };
	NSMutableString* result = [trimmed mutableCopy];
	for (int i = 0; i < sizeof(invis)/sizeof(invis[0]); i++) {
		unichar c = (unichar)invis[i];
		NSString* s = [NSString stringWithCharacters:&c length:1];
		[result replaceOccurrencesOfString:s withString:@"" options:0 range:NSMakeRange(0, result.length)];
	}

	// icu quotes literals with ASCII apostrophe; drop them
	[result replaceOccurrencesOfString:@"'" withString:@"" options:0 range:NSMakeRange(0, result.length)];

	return result.length ? result : @"/"; // sensible fallback
}

@implementation NSLocale (Format)

+ (NSDictionary *) mb_localeInfoAutoupdating
{
	return [[NSLocale autoupdatingCurrentLocale] mb_localeInfo];
}

- (NSDictionary *) mb_localeInfo
{
	NSString* hour = [self mb_hourCycle];
	NSString* order = [self mb_dateOrder];
	NSString* sep = [self mb_dateSeparator];

	return @{
		@"hourCycle": hour,
		@"dateOrder": order,
		@"separator": sep,
		@"locale": self.localeIdentifier ?: @""
	};
}

- (NSString *) mb_hourCycle
{
	// expand "j" skeleton to see whether this locale prefers h/K (12h) or H/k (24h)
	NSString* timePattern = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:self];
	BOOL is_12h = ([timePattern rangeOfString:@"h"].location != NSNotFound || [timePattern rangeOfString:@"K"].location != NSNotFound);
	return is_12h ? @"h12" : @"h24";
}

- (NSString *) mb_dateOrder
{
	// use canonical short date pattern
	NSString* date_pattern = [NSDateFormatter dateFormatFromTemplate:@"yMd" options:0 locale:self];

	NSError* err = nil;
	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"y+|M+|d+" options:0 error:&err];
	NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:date_pattern options:0 range:NSMakeRange(0, date_pattern.length)];

	NSMutableString* order = [NSMutableString string];
	for (NSTextCheckingResult* m in matches) {
		unichar c = [date_pattern characterAtIndex:m.range.location];
		if (c == 'M') {
			[order appendString:@"M"];
		}
		else if (c == 'd') {
			[order appendString:@"D"];
		}
		else if (c == 'y') {
			[order appendString:@"Y"];
		}
	}

	if (order.length == 3) {
		return order;
	}
	
	// fallback to MDY
	return @"MDY";
}

- (NSString *) mb_dateSeparator
{
	NSString* date_pattern = [NSDateFormatter dateFormatFromTemplate:@"yMd" options:0 locale:self];

	NSError* err = nil;
	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"y+|M+|d+" options:0 error:&err];
	NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:date_pattern options:0 range:NSMakeRange(0, date_pattern.length)];

	if (matches.count >= 2) {
		NSRange r1 = matches[0].range;
		NSRange r2 = matches[1].range;
		NSRange sepRange = NSMakeRange(NSMaxRange(r1), r2.location - NSMaxRange(r1));
		if (NSMaxRange(sepRange) <= date_pattern.length) {
			NSString* raw_sep = [date_pattern substringWithRange:sepRange];
			return MBNormalizeDateSeparator(raw_sep);
		}
	}
	return @"/"; // fallback
}

@end
