//
//  NSColor+Extras.m
//  Micro.blog
//
//  Created by Manton Reece on 2/12/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "NSColor+Extras.h"

@implementation NSColor (Extras)

+ (NSColor *) mb_colorFromString:(NSString *)hexString
{
	// remove "#" if there
	hexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
	
	// convert hex string to integer value
	NSScanner *scanner = [NSScanner scannerWithString:hexString];
	unsigned int value = 0;
	[scanner scanHexInt:&value];
	
	// extract red, green, blue components
	CGFloat red = ((value & 0xFF0000) >> 16) / 255.0;
	CGFloat green = ((value & 0x00FF00) >> 8) / 255.0;
	CGFloat blue = (value & 0x0000FF) / 255.0;
	
	// make NSColor
	return [NSColor colorWithRed:red green:green blue:blue alpha:1.0];
}

@end
