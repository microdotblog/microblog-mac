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
#import "UUDate.h"

@implementation RFPost

- (id) initFromProperties:(NSDictionary *)props
{
	self = [super init];
	if (self) {
		self.title = [[props objectForKey:@"name"] firstObject];
		self.text = [[props objectForKey:@"content"] firstObject];
		self.summary = [[props objectForKey:@"summary"] firstObject];
		self.url = [[props objectForKey:@"url"] firstObject];

		NSString* date_s = [[props objectForKey:@"published"] firstObject];
		self.postedAt = [NSDate uuDateFromRfc3339String:date_s];

		NSString* status = [[props objectForKey:@"post-status"] firstObject];
		self.isDraft = [status isEqualToString:@"draft"];
		
		self.categories = @[];
		if ([[props objectForKey:@"category"] count] > 0) {
			self.categories = [props objectForKey:@"category"];
		}

		self.syndication = @[];
		if ([[props objectForKey:@"syndication"] count] > 0) {
			self.syndication = [props objectForKey:@"syndication"];
		}
	}
	
	return self;
}

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
