//
//  RFPost.m
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPost.h"

#import "NSString+Extras.h"
#import "MMMarkdown.h"

@implementation RFPost

- (NSString *) displaySummary
{
	NSString* s = @"";
	NSError* error = nil;
	NSString* html = [MMMarkdown HTMLStringWithMarkdown:self.text error:&error];
	if (html.length > 0) {
		s = [html rf_stripHTML];
		
		// special case to fix shortcodes
		s = [s stringByReplacingOccurrencesOfString:@"{{&lt; " withString:@"{{< "];

		if (s.length > 300) {
			s = [s substringToIndex:300];
			s = [s stringByAppendingString:@"..."];
		}
		
		s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	}
	
	return s;
}

- (BOOL) isPage
{
	return [self.channel isEqualToString:@"pages"];
}

@end
