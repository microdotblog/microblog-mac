//
//  NSString+Extras.m
//  Snippets
//
//  Created by Manton Reece on 8/26/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "NSString+Extras.h"

@implementation NSString (Extras)

- (NSNumber *) rf_numberValue
{
	NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterDecimalStyle;
	return [f numberFromString:self];
}

- (NSString *) rf_urlEncoded
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
}

- (NSString *) rf_stripHTML
{
	NSRange r;
	NSString* s = [self copy];
	while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound) {
		s = [s stringByReplacingCharactersInRange:r withString:@""];
	}
	
	return s;
}

- (NSString *) rf_stringEscapingQuotes
{
	return [self stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

@end
