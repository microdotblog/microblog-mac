//
//  RFAccount.m
//  Snippets
//
//  Created by Manton Reece on 3/22/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFAccount.h"

@implementation RFAccount

+ (NSString *) autosaveDraftFile
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains (NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSError* error = nil;
	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	[[NSFileManager defaultManager] createDirectoryAtPath:microblog_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* draft_file = [microblog_folder stringByAppendingPathComponent:@"Draft.md"];
	return draft_file;
}

+ (NSString *) cachedProfileFolder
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains (NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSError* error = nil;
	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	[[NSFileManager defaultManager] createDirectoryAtPath:microblog_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* images_folder = [microblog_folder stringByAppendingPathComponent:@"Profile Images"];
	[[NSFileManager defaultManager] createDirectoryAtPath:images_folder withIntermediateDirectories:YES attributes:nil error:&error];

	return images_folder;
}

- (NSString *) cachedProfileFile
{
	NSString* folder = [[self class] cachedProfileFolder];
	NSString* filename = [NSString stringWithFormat:@"%@.tif", self.username];
	return [folder stringByAppendingPathComponent:filename];
}

- (NSString *) profileImageURL
{
	if (self.username.length > 0) {
		return [NSString stringWithFormat:@"https://micro.blog/%@/avatar.jpg", self.username];
		}
	else {
		return nil;
	}
}

- (NSImage *) cachedProfileImage
{
	NSImage* img = [[NSImage alloc] initWithContentsOfFile:[self cachedProfileFile]];
	return img;
}

- (void) saveProfileImage:(NSImage *)image
{
	NSString* file = [self cachedProfileFile];
	NSData* d = [image TIFFRepresentation];
	[d writeToFile:file atomically:NO];
}

+ (void) clearCache
{
	NSString* folder = [self cachedProfileFolder];
	NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
	for (NSString* filename in filenames) {
		NSString* file = [folder stringByAppendingPathComponent:filename];
		if ([file containsString:@"Micro.blog"] && [[file pathExtension] isEqualToString:@"tif"]) {
			// sanity check the path before deleting anything
			[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
		}
	}
}

@end
