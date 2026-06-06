//
//  MBCategory.m
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBCategory.h"

@implementation MBCategory

- (instancetype) initWithName:(NSString *)name postsCount:(NSNumber *)postsCount
{
	self = [super init];
	if (self) {
		self.name = name ?: @"";
		self.postsCount = postsCount;
	}

	return self;
}

+ (NSArray *) categoriesFromResponse:(NSDictionary *)response
{
	NSMutableArray* results = [NSMutableArray array];
	NSArray* categories = [response objectForKey:@"microblog-categories"];
	if (![categories isKindOfClass:[NSArray class]]) {
		categories = [response objectForKey:@"categories"];
	}

	for (id category_info in categories) {
		MBCategory* category = [self categoryFromObject:category_info];
		if (category.name.length > 0) {
			[results addObject:category];
		}
	}

	return results;
}

+ (MBCategory *) categoryFromObject:(id)categoryInfo
{
	if ([categoryInfo isKindOfClass:[NSString class]]) {
		return [[MBCategory alloc] initWithName:categoryInfo postsCount:nil];
	}
	else if ([categoryInfo isKindOfClass:[NSDictionary class]]) {
		NSDictionary* info = (NSDictionary *)categoryInfo;
		NSString* name = [info objectForKey:@"name"];
		if (name.length == 0) {
			name = [info objectForKey:@"category"];
		}
		if (name.length == 0) {
			name = [info objectForKey:@"title"];
		}

		NSNumber* count = [self countFromDictionary:info];
		MBCategory* category = [[MBCategory alloc] initWithName:name postsCount:count];
		category.uid = [self numberFromObject:[info objectForKey:@"uid"]];
		category.url = [self stringFromObject:[info objectForKey:@"url"]];
		return category;
	}
	else {
		return [[MBCategory alloc] initWithName:@"" postsCount:nil];
	}
}

+ (NSNumber *) countFromDictionary:(NSDictionary *)info
{
	NSArray* keys = @[ @"count", @"posts_count", @"post_count" ];
	for (NSString* key in keys) {
		id value = [info objectForKey:key];
		if ([value isKindOfClass:[NSNumber class]]) {
			return value;
		}
		else if ([value isKindOfClass:[NSString class]]) {
			return @([(NSString *)value integerValue]);
		}
	}

	NSDictionary* microblog_info = [info objectForKey:@"_microblog"];
	if ([microblog_info isKindOfClass:[NSDictionary class]]) {
		return [self countFromDictionary:microblog_info];
	}
	else {
		return nil;
	}
}

+ (NSNumber *) numberFromObject:(id)value
{
	if ([value isKindOfClass:[NSNumber class]]) {
		return value;
	}
	else if ([value isKindOfClass:[NSString class]]) {
		return @([(NSString *)value integerValue]);
	}
	else {
		return nil;
	}
}

+ (NSString *) stringFromObject:(id)value
{
	if ([value isKindOfClass:[NSString class]]) {
		return value;
	}
	else if ([value isKindOfClass:[NSNumber class]]) {
		return [(NSNumber *)value stringValue];
	}
	else {
		return nil;
	}
}

@end
