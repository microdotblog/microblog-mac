//
//  RFAutoCompleteCache.m
//  Snippets
//
//  Created by Jonathan Hays on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//


#import "RFAutoCompleteCache.h"
#import "UUString.h"
#import "RFConstants.h"

@implementation RFAutoCompleteCache

+ (NSArray*) allAutoCompleteStrings
{
	NSUserDefaults* sharedDefaults = [NSUserDefaults standardUserDefaults];// [[NSUserDefaults alloc] initWithSuiteName: kSharedGroupDefaults];
	NSArray* strings = [sharedDefaults objectForKey:@"RFAutoCompleteCache"];
	return strings;
}

+ (void) setAutoCompleteStrings:(NSArray*)array
{
	NSUserDefaults* sharedDefaults = [NSUserDefaults standardUserDefaults];// [[NSUserDefaults alloc] initWithSuiteName: kSharedGroupDefaults];
	[sharedDefaults setObject:array forKey:@"RFAutoCompleteCache"];
}

+ (void) addAutoCompleteString:(NSString*)inString
{
	NSString* string = inString;
	if ([string uuStartsWithSubstring:@"@"])
		string = [string substringFromIndex:1];
	
	NSMutableArray* newStrings = [NSMutableArray array];
	NSArray* oldStrings = [RFAutoCompleteCache allAutoCompleteStrings];
	if (oldStrings)
	{
		newStrings = [NSMutableArray arrayWithArray:oldStrings];
	}
	
	if (![newStrings containsObject:string])
	{
		[newStrings addObject:string];
		[RFAutoCompleteCache setAutoCompleteStrings:newStrings];
	}
}

+ (void) findAutoCompleteFor:(NSString*)inString completion:(void (^)(NSArray* results))completion
{
	NSString* string = inString;
	if ([string uuStartsWithSubstring:@"@"])
		string = [string substringFromIndex:1];
	
	NSMutableArray* foundStrings = [NSMutableArray array];
	NSArray* autoCompleteStrings = [RFAutoCompleteCache allAutoCompleteStrings];
	for (NSString* autoCompleteString in autoCompleteStrings)
	{
		if ([autoCompleteString.lowercaseString uuStartsWithSubstring:string.lowercaseString])
		{
			if (![autoCompleteString.lowercaseString isEqualToString:string.lowercaseString])
			{
				[foundStrings addObject:autoCompleteString];
			}
		}
	}
	
	completion(foundStrings);
}


@end
