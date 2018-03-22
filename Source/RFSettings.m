//
//  RFSettings.m
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFSettings.h"

#import "RFAccount.h"

@implementation RFSettings

+ (NSArray *) accounts
{
	NSArray* results = @[];
	
	NSArray* users = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AccountUsernames"];
	if ((users == nil) || (users.count == 0)) {
		RFAccount* a = [[RFAccount alloc] init];
		a.username = @"manton";
		results = @[ a ];
	}
	else {
		NSMutableArray* new_accounts = [[NSMutableArray alloc] init];
		for (NSString* username in users) {
			RFAccount* a = [[RFAccount alloc] init];
			a.username = username;
			[new_accounts addObject:a];
		}
		results = new_accounts;
	}
	
	return results;
}

@end
