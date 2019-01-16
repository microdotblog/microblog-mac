//
//  RFUserCache.h
//  Snippets
//
//  Created by Jonathan Hays on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFUserCache : NSObject

+ (NSDictionary*) user:(NSString*)user;
+ (void) setCache:(NSDictionary*)userInfo forUser:(NSString*)user;

+ (NSImage*) avatar:(NSURL*)url completionHandler:(void(^)(NSImage* image)) completionHandler;
+ (void) cacheAvatar:(NSImage*)image forURL:(NSURL*)url;

@end


NS_ASSUME_NONNULL_END
