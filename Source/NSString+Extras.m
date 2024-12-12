//
//  NSString+Extras.m
//  Snippets
//
//  Created by Manton Reece on 8/26/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "NSString+Extras.h"

#import <Cocoa/Cocoa.h>

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

- (NSString *) mb_contentType
{
	NSString* filename = [self lastPathComponent];
	NSString* e = [filename pathExtension];
	NSString* uti = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)e, NULL);
	NSString* content_type = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
	return content_type;
}

+ (NSString *) mb_openInBrowserString
{
	NSString* browser_s = @"Open in Browser";
	
	NSURL* example_url = [NSURL URLWithString:@"https://micro.blog/"];
	NSURL* app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:example_url];

	if ([app_url.lastPathComponent containsString:@"Chrome"]) {
		browser_s = @"Open in Chrome";
	}
	else if ([app_url.lastPathComponent containsString:@"Firefox"]) {
		browser_s = @"Open in Firefox";
	}
	else if ([app_url.lastPathComponent containsString:@"Safari"]) {
		browser_s = @"Open in Safari";
	}
	else if ([app_url.lastPathComponent containsString:@"Arc"]) {
		browser_s = @"Open in Arc";
	}
	else if ([app_url.lastPathComponent containsString:@"Dia"]) {
		browser_s = @"Open in Dia";
	}

	return browser_s;
}

@end
