//
//  MBCategory.h
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBCategory : NSObject

@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic, nullable) NSNumber* uid;
@property (strong, nonatomic, nullable) NSString* url;
@property (strong, nonatomic, nullable) NSNumber* postsCount;

- (instancetype) initWithName:(NSString *)name postsCount:(nullable NSNumber *)postsCount;
+ (NSArray *) categoriesFromResponse:(NSDictionary *)response;
+ (MBCategory *) categoryFromObject:(id)categoryInfo;

@end

NS_ASSUME_NONNULL_END
