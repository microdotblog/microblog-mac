//
//  RFUserCache.m
//  Snippets
//
//  Created by Jonathan Hays on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

@import AppKit;

#import "RFUserCache.h"
#import "RFUserCache.h"
#import "RFAutoCompleteCache.h"
#import "UUHttpSession.h"
#import "UUDataCache.h"

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
	});
	
	return theSharedObject;
}



+ (NSImage*) avatar:(NSURL*)url completionHandler:(void(^)(NSImage* image)) completionHandler
{
	NSImage* image = [[RFUserCache systemImageCache] objectForKey:url.absoluteString];
	if (image)
	{
		return image;
	}
	
	dispatch_async([RFUserCache imageProcessingQueue], ^{
		NSData* cachedData = [UUDataCache uuDataForURL:url];
		NSImage* image = [[NSImage alloc] initWithData:cachedData];
		if (image)
		{
			[[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				completionHandler(image);
			});
			return;
		}
		
		[UUHttpSession get:url.absoluteString queryArguments:nil completionHandler:^(UUHttpResponse *response)
		 {
			 if ([response.parsedResponse isKindOfClass:[NSImage class]])
			 {
				 NSImage* image = response.parsedResponse;
				 NSData* data = image.TIFFRepresentation;
				 [UUDataCache uuCacheData:data forURL:url];
				 [[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
				 
				 dispatch_async(dispatch_get_main_queue(), ^{
					 completionHandler(image);
				 });
			 }
		 }];
		
	});
	
	return  nil;
}

+ (void) cacheAvatar:(NSImage*)image forURL:(NSURL*)url
{
	[[RFUserCache systemImageCache] setObject:image forKey:url.absoluteString];
	
	dispatch_async([RFUserCache imageProcessingQueue], ^{
		NSData* data = image.TIFFRepresentation;
		[UUDataCache uuCacheData:data forURL:url];
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
