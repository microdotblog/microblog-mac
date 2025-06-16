//
//  NSAppearance+Extras.m
//  Snippets
//
//  Created by Manton Reece on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "NSAppearance+Extras.h"

@implementation NSAppearance (Extras)

+ (BOOL) rf_isDarkMode
{
	BOOL is_dark = NO;
	
	if (@available(macOS 10.14, *)) {
//		NSAppearance* mode = [NSAppearance currentAppearance];
		NSAppearance* mode = [[NSApplication sharedApplication] effectiveAppearance];
		is_dark = [mode rf_isDarkMode];
	}
	
	return is_dark;
}

- (BOOL) rf_isDarkMode
{
	BOOL is_dark = NO;
	
	if (@available(macOS 10.14, *)) {
		is_dark = [[self bestMatchFromAppearancesWithNames:@[ NSAppearanceNameDarkAqua, NSAppearanceNameAqua ]] isEqualToString:NSAppearanceNameDarkAqua];
	}
	
	return is_dark;
}

+ (BOOL) mb_isLiquidGlass
{
	if (@available(macOS 26.0, *)) {
		return YES;
	}
	else {
		return NO;
	}
}

@end
