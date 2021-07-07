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
	NSMutableArray* new_accounts = [[NSMutableArray alloc] init];
	NSArray* users = [[NSUserDefaults standardUserDefaults] arrayForKey:kAccountUsernames];

//	users = [users sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
//		return [obj1 compare:obj2];
//	}];
	
	for (NSString* username in users) {
		RFAccount* a = [[RFAccount alloc] init];
		a.username = username;
		[new_accounts addObject:a];
	}
	
	return new_accounts;
}

+ (RFAccount *) defaultAccount
{
	NSString* username = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentUsername];
	NSArray* accounts = [self accounts];
	RFAccount* found_account = nil;
	if (username) {
		for (RFAccount* a in accounts) {
			if ([a.username isEqualToString:username]) {
				found_account = a;
				break;
			}
		}
	}
	
	if (found_account) {
		return found_account;
	}
	else {
		return [accounts firstObject];
	}
}

+ (void) addAccount:(RFAccount *)account
{
	NSArray* usernames = [[NSUserDefaults standardUserDefaults] arrayForKey:kAccountUsernames];
	NSMutableArray* new_usernames = nil;
	if (usernames.count == 0) {
		new_usernames = [NSMutableArray arrayWithObject:account.username];
	}
	else {
		BOOL found = NO;
		for (NSString* username in usernames) {
			if ([username isEqualToString:account.username]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			new_usernames = [usernames mutableCopy];
			[new_usernames addObject:account.username];
		}
	}

	if (new_usernames) {
		[[NSUserDefaults standardUserDefaults] setObject:new_usernames forKey:kAccountUsernames];
	}
}

+ (void) removeAccount:(RFAccount *)account
{
	NSArray* usernames = [[NSUserDefaults standardUserDefaults] arrayForKey:kAccountUsernames];
	NSMutableArray* new_usernames = [usernames mutableCopy];
	[new_usernames removeObject:account.username];
	[[NSUserDefaults standardUserDefaults] setObject:new_usernames forKey:kAccountUsernames];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentUsername];
}

+ (void) migrateSettings
{
	NSString* username = [[NSUserDefaults standardUserDefaults] objectForKey:kAccountUsername];
	if (username.length > 0) {
		NSArray* keys = @[ kExternalBlogIsPreferred, kAccountUsername, kAccountFullName, kAccountDefaultSite, kAccountEmail, kAccountGravatarURL, kHasSnippetsBlog, kIsFullAccess, kExternalMicropubState, kExternalMicropubTokenEndpoint, kExternalMicropubMe, kExternalBlogUsername, kExternalBlogEndpoint, kExternalBlogID, kExternalBlogApp, kExternalBlogURL, kExternalMicropubPostingEndpoint, kExternalMicropubMediaEndpoint, kCurrentDestinationUID, kCurrentDestinationName, kExternalBlogFormat, kExternalBlogCategory ];
		for (NSString* old_k in keys) {
			NSString* new_k = [NSString stringWithFormat:@"%@_%@", username, old_k];
			id val = [[NSUserDefaults standardUserDefaults] objectForKey:old_k];
			[[NSUserDefaults standardUserDefaults] setObject:val forKey:new_k];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:old_k];
		}
		
		NSArray* new_usernames = [NSArray arrayWithObject:username];
		[[NSUserDefaults standardUserDefaults] setObject:new_usernames forKey:kAccountUsernames];
		[[NSUserDefaults standardUserDefaults] setObject:username forKey:kCurrentUsername];
	}
}

#pragma mark -

+ (BOOL) hasSnippetsBlog
{
	return [self boolForKey:kHasSnippetsBlog];
}

+ (BOOL) hasMicropubBlog
{
	return ([self stringForKey:kExternalMicropubMe] != nil);
}

+ (BOOL) prefersExternalBlog
{
	return [self boolForKey:kExternalBlogIsPreferred];
}

+ (BOOL) isUsingMicroblog
{
	return [self hasSnippetsBlog] && ![self prefersExternalBlog];
}

#pragma mark -

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
