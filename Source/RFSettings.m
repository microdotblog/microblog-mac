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
		RFAccount* a2 = [[RFAccount alloc] init];
		a2.username = @"timetable";
		RFAccount* a3 = [[RFAccount alloc] init];
		a3.username = @"monday";
		results = @[ a, a2, a3 ];
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

+ (RFAccount *) defaultAccount
{
	return [[self accounts] firstObject];
}

+ (void) migrateSettings
{
}

+ (BOOL) boolForKey:(NSString *)prefKey
{
	return [self boolForKey:prefKey account:[self defaultAccount]];
}

+ (BOOL) boolForKey:(NSString *)prefKey account:(RFAccount *)account
{
	NSString* k = [NSString stringWithFormat:@"%@_%@", account.username, prefKey];
	return [[NSUserDefaults standardUserDefaults] boolForKey:k];
}

+ (void) setBool:(BOOL)value forKey:(NSString *)prefKey
{
	[self setBool:value forKey:prefKey account:[self defaultAccount]];
}

+ (void) setBool:(BOOL)value forKey:(NSString *)prefKey account:(RFAccount *)account
{
	NSString* k = [NSString stringWithFormat:@"%@_%@", account.username, prefKey];
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:k];
}

#pragma mark -

+ (NSString *) stringForKey:(NSString *)prefKey
{
	return [self stringForKey:prefKey account:[self defaultAccount]];
}

+ (NSString *) stringForKey:(NSString *)prefKey account:(RFAccount *)account
{
	NSString* k = [NSString stringWithFormat:@"%@_%@", account.username, prefKey];
	return [[NSUserDefaults standardUserDefaults] stringForKey:k];
}

+ (void) setString:(NSString *)value forKey:(NSString *)prefKey
{
	[self setString:value forKey:prefKey account:[self defaultAccount]];
}

+ (void) setString:(NSString *)value forKey:(NSString *)prefKey account:(RFAccount *)account
{
	NSString* k = [NSString stringWithFormat:@"%@_%@", account.username, prefKey];
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:k];
}

#pragma mark -

+ (void) removeObjectForKey:(NSString *)prefKey
{
	[self removeObjectForKey:prefKey account:[self defaultAccount]];
}

+ (void) removeObjectForKey:(NSString *)prefKey account:(RFAccount *)account
{
	NSString* k = [NSString stringWithFormat:@"%@_%@", account.username, prefKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:k];
}

@end
