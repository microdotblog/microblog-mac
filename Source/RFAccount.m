//
//  RFAccount.m
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFAccount.h"

@implementation RFAccount

- (NSString *) profileImageURL
{
	if (self.username.length > 0) {
		return [NSString stringWithFormat:@"https://micro.blog/%@/avatar.jpg", self.username];
		}
	else {
		return nil;
	}
}

@end
