//
//  MBBook.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBook.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MBBook

- (NSString *) microblogURL;
{
	return [NSString stringWithFormat:@"https://micro.blog/books/%@", self.isbn];
}

- (NSString *) pathForCachedCover
{
	if (self.isbn.length == 0 || ![self.isbn.lastPathComponent isEqualToString:self.isbn]) {
		return nil;
	}
	NSString* filename = [NSString stringWithFormat:@"%@.tif", self.isbn];
	return [[self class] pathForCachedImage:filename inFolder:@"Book Covers"];
}

- (NSString *) pathForCachedBackground
{
	if (self.backgroundURL.length == 0) {
		return nil;
	}

	// Match the calendar's URL-based filenames so both views share the cache.
	NSData* url_data = [self.backgroundURL dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256(url_data.bytes, (CC_LONG)url_data.length, digest);
	NSMutableString* filename = [NSMutableString string];
	for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
		[filename appendFormat:@"%02x", digest[i]];
	}
	[filename appendString:@".tif"];
	return [[self class] pathForCachedImage:filename inFolder:@"Book Backgrounds"];
}

+ (NSString *) pathForCachedImage:(NSString *)filename inFolder:(NSString *)folderName
{
	if (filename.length == 0 || ![filename.lastPathComponent isEqualToString:filename]) {
		return nil;
	}

	NSArray* paths = NSSearchPathForDirectoriesInDomains (NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	NSString* cache_folder = [microblog_folder stringByAppendingPathComponent:folderName];
	if (![[NSFileManager defaultManager] createDirectoryAtPath:cache_folder withIntermediateDirectories:YES attributes:nil error:nil]) {
		return nil;
	}

	return [cache_folder stringByAppendingPathComponent:filename];
}

- (NSImage *) cachedCover
{
	NSString* path = [self pathForCachedCover];
	NSImage* img = path ? [[NSImage alloc] initWithContentsOfFile:path] : nil;
	return img;
}

- (void) setCachedCover:(NSImage *)image;
{
	NSData* d = [image TIFFRepresentation];
	NSString* path = [self pathForCachedCover];
	if (path) {
		[d writeToFile:path atomically:YES];
	}
}

@end
