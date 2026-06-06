//
//  RFUserCache.m
//  Snippets
//
//  Created by Jonathan Hays on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

@import AppKit;

#import "RFUserCache.h"
#import "RFAutoCompleteCache.h"
#import "UUHttpSession.h"

#import <CommonCrypto/CommonDigest.h>

static NSTimeInterval const kAvatarCacheExpirationSeconds = (60 * 60 * 24 * 3);
static NSTimeInterval const kProfileImagesCleanupExpirationSeconds = (60 * 60 * 24 * 14);

@implementation RFUserCache


+ (dispatch_queue_t) imageProcessingQueue
{
	static id theImageProcessingQueue = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once (&onceToken, ^{
		theImageProcessingQueue = dispatch_queue_create("blog.micro.imagequeue", 0);
	});
	
	return theImageProcessingQueue;
	
}

+ (NSCache*) systemImageCache
{
	static id theSharedObject = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once (&onceToken, ^{
		theSharedObject = [[NSCache alloc] init];
		[theSharedObject setCountLimit:200];
	});
	
	return theSharedObject;
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

+ (NSString *) shortHashForURL:(NSURL *)url
{
	NSData* data = [url.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1(data.bytes, (CC_LONG)data.length, digest);

	NSMutableString* result = [NSMutableString string];
	for (NSInteger i = 0; i < 6; i++) {
		[result appendFormat:@"%02x", digest[i]];
	}

	return result;
}

+ (NSString *) sanitizedDomainForURL:(NSURL *)url
{
	NSString* domain = url.host.lowercaseString;
	if (domain.length == 0) {
		domain = @"avatar";
	}

	NSMutableCharacterSet* allowed = [NSMutableCharacterSet alphanumericCharacterSet];
	[allowed addCharactersInString:@".-"];

	NSArray* parts = [domain componentsSeparatedByCharactersInSet:[allowed invertedSet]];
	NSString* result = [parts componentsJoinedByString:@"-"];
	if (result.length == 0) {
		result = @"avatar";
	}

	return result;
}

+ (NSString *) avatarFilenamePrefixForURL:(NSURL *)url
{
	return [NSString stringWithFormat:@"%@-%@", [self sanitizedDomainForURL:url], [self shortHashForURL:url]];
}

+ (NSString *) normalizedImageExtension:(NSString *)extension
{
	NSString* result = extension.lowercaseString;
	if (result.length == 0) {
		return nil;
	}

	if ([result isEqualToString:@"jpeg"]) {
		result = @"jpg";
	}

	NSSet* allowed_extensions = [NSSet setWithArray:@[ @"jpg", @"png", @"gif", @"webp", @"tif", @"tiff", @"heic", @"heif" ]];
	if (![allowed_extensions containsObject:result]) {
		result = nil;
	}

	return result;
}

+ (NSString *) avatarExtensionForMIMEType:(NSString *)mimeType
{
	if (mimeType.length == 0) {
		return nil;
	}

	NSDictionary* extensions = @{
		@"image/jpeg": @"jpg",
		@"image/jpg": @"jpg",
		@"image/png": @"png",
		@"image/gif": @"gif",
		@"image/webp": @"webp",
		@"image/tiff": @"tif",
		@"image/tif": @"tif",
		@"image/heic": @"heic",
		@"image/heif": @"heif"
	};

	return [extensions objectForKey:mimeType.lowercaseString];
}

+ (NSString *) avatarExtensionForImageData:(NSData *)data
{
	if (data.length < 4) {
		return nil;
	}

	const unsigned char* bytes = data.bytes;
	if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
		return @"jpg";
	}
	if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) {
		return @"png";
	}
	if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
		return @"gif";
	}
	if (data.length >= 12 &&
		bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
		bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
		return @"webp";
	}
	if ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2a && bytes[3] == 0x00) ||
		(bytes[0] == 0x4d && bytes[1] == 0x4d && bytes[2] == 0x00 && bytes[3] == 0x2a)) {
		return @"tif";
	}
	if (data.length >= 12 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
		NSString* brand = [[NSString alloc] initWithBytes:&bytes[8] length:4 encoding:NSASCIIStringEncoding];
		if ([brand hasPrefix:@"hei"] || [brand isEqualToString:@"mif1"]) {
			return @"heic";
		}
	}

	return nil;
}

+ (NSString *) avatarCachePathForURL:(NSURL *)url extension:(NSString *)extension
{
	NSString* filename = [NSString stringWithFormat:@"%@.%@", [self avatarFilenamePrefixForURL:url], extension];
	return [[self cachedProfileFolder] stringByAppendingPathComponent:filename];
}

+ (NSString *) existingAvatarCachePathForURL:(NSURL *)url
{
	NSString* folder = [self cachedProfileFolder];
	NSString* prefix = [NSString stringWithFormat:@"%@.", [self avatarFilenamePrefixForURL:url]];
	NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];

	for (NSString* filename in filenames) {
		if ([filename hasPrefix:prefix]) {
			return [folder stringByAppendingPathComponent:filename];
		}
	}

	return nil;
}

+ (BOOL) profileImageFileAtPath:(NSString *)path isOlderThan:(NSTimeInterval)maxAge
{
	NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
	NSDate* created_date = [attributes objectForKey:NSFileCreationDate];
	if (created_date == nil) {
		return NO;
	}

	NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:created_date];
	return (age > maxAge);
}

+ (BOOL) safelyDeleteFileAtPath:(NSString *)path
{
	NSString* full_path = [path stringByStandardizingPath];
	if (full_path.length == 0) {
		return NO;
	}

	if (![full_path containsString:@"Application Support"] || ![full_path containsString:@"Micro.blog"]) {
		return NO;
	}

	BOOL is_dir = NO;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:full_path isDirectory:&is_dir];
	if (!exists || is_dir) {
		return NO;
	}

	return [[NSFileManager defaultManager] removeItemAtPath:full_path error:NULL];
}

+ (BOOL) expireAvatarCacheFilesForURL:(NSURL *)url
{
	BOOL did_expire = NO;
	NSString* folder = [self cachedProfileFolder];
	NSString* prefix = [NSString stringWithFormat:@"%@.", [self avatarFilenamePrefixForURL:url]];
	NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];

	for (NSString* filename in filenames) {
		if ([filename hasPrefix:prefix]) {
			NSString* path = [folder stringByAppendingPathComponent:filename];
			if ([self profileImageFileAtPath:path isOlderThan:kAvatarCacheExpirationSeconds]) {
				did_expire = ([self safelyDeleteFileAtPath:path] || did_expire);
			}
		}
	}

	return did_expire;
}

+ (void) writeAvatarData:(NSData *)data forURL:(NSURL *)url extension:(NSString *)extension
{
	if (data.length == 0 || url == nil) {
		return;
	}

	NSString* path = [self avatarCachePathForURL:url extension:extension];
	[data writeToFile:path atomically:YES];
}

+ (void) cleanupExpiredProfileImages
{
	NSString* folder = [self cachedProfileFolder];
	NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];

	for (NSString* filename in filenames) {
		NSString* path = [folder stringByAppendingPathComponent:filename];
		if ([self profileImageFileAtPath:path isOlderThan:kProfileImagesCleanupExpirationSeconds]) {
			[self safelyDeleteFileAtPath:path];
		}
	}
}



+ (NSImage *) avatar:(NSURL *)url completionHandler:(void(^)(NSImage *image)) completionHandler
{
	if (url == nil) {
		return nil;
	}

	if ([RFUserCache expireAvatarCacheFilesForURL:url]) {
		[[RFUserCache systemImageCache] removeObjectForKey:url.absoluteString];
	}

	NSImage* image = [[RFUserCache systemImageCache] objectForKey:url.absoluteString];
	if (image)
	{
		return image;
	}
	
	dispatch_async([RFUserCache imageProcessingQueue], ^{
		NSString* cached_file = [RFUserCache existingAvatarCachePathForURL:url];
		NSImage* image = nil;
		if (cached_file.length > 0) {
			image = [[NSImage alloc] initWithContentsOfFile:cached_file];
		}
		if (image)
		{
			[[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				if (completionHandler) {
					completionHandler(image);
				}
			});
			return;
		}
		
		[UUHttpSession get:url.absoluteString queryArguments:nil completionHandler:^(UUHttpResponse *response)
		 {
			 NSImage* image = nil;
			 if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				 image = response.parsedResponse;
			 }
			 else if (response.rawResponse.length > 0) {
				 image = [[NSImage alloc] initWithData:response.rawResponse];
			 }

			 if (image != nil)
			 {
				 NSString* extension = [RFUserCache avatarExtensionForMIMEType:response.httpResponse.MIMEType];
				 extension = extension ?: [RFUserCache normalizedImageExtension:url.pathExtension];
				 NSData* data = response.rawResponse;
				 extension = extension ?: [RFUserCache avatarExtensionForImageData:data];
				 if (data.length == 0) {
					 data = image.TIFFRepresentation;
					 extension = @"tif";
				 }
				 [RFUserCache writeAvatarData:data forURL:url extension:(extension ?: @"tif")];
				 [[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
				 
				 dispatch_async(dispatch_get_main_queue(), ^{
					 if (completionHandler) {
						 completionHandler(image);
					 }
				 });
			 }
		 }];
		
	});
	
	return  nil;
}

+ (void) cacheAvatar:(NSImage *)image forURL:(NSURL *)url
{
	if (image == nil || url == nil) {
		return;
	}

	[[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
	
	dispatch_async([RFUserCache imageProcessingQueue], ^{
		NSData* data = image.TIFFRepresentation;
		[RFUserCache writeAvatarData:data forURL:url extension:@"tif"];
	});
}

+ (NSDictionary*) user:(NSString*)user
{
	NSDictionary* dictionary = [[NSUserDefaults standardUserDefaults] objectForKey:user];
	return dictionary;
}

+ (void) setCache:(NSDictionary*)userInfo forUser:(NSString*)user
{
	[[NSUserDefaults standardUserDefaults] setObject:userInfo forKey:user];
	
	[RFAutoCompleteCache addAutoCompleteString:user];
}

@end
