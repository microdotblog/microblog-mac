//
//  RFPost.m
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPost.h"

#import "NSString+Extras.h"

@implementation RFPost

- (NSString *) summary
{
	NSString* s = [self.text rf_stripHTML];

	if (s.length > 300) {
		s = [s substringToIndex:300];
		s = [s stringByAppendingString:@"..."];
	}
	
	return s;
}

@end
