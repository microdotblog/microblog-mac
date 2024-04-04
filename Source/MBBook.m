//
//  MBBook.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBook.h"

@implementation MBBook

- (NSString *) microblogURL;
{
	return [NSString stringWithFormat:@"https://micro.blog/books/%@", self.isbn];
}

- (NSString *) pathForCachedCover
{
	NSString* filename = [NSString stringWithFormat:@"%@.tif", self.isbn];

	NSArray* paths = NSSearchPathForDirectoriesInDomains (NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSError* error = nil;
	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	[[NSFileManager defaultManager] createDirectoryAtPath:microblog_folder withIntermediateDirectories:YES attributes:nil error:&error];
	
	NSString* covers_folder = [microblog_folder stringByAppendingPathComponent:@"Book Covers"];
	[[NSFileManager defaultManager] createDirectoryAtPath:covers_folder withIntermediateDirectories:YES attributes:nil error:&error];

	return [covers_folder stringByAppendingPathComponent:filename];
}

- (NSImage *) cachedCover
{
	NSImage* img = [[NSImage alloc] initWithContentsOfFile:[self pathForCachedCover]];
	return img;
}

- (void) setCachedCover:(NSImage *)image;
{
	NSData* d = [image TIFFRepresentation];
	[d writeToFile:[self pathForCachedCover] atomically:NO];
}

@end
