//
//  MBVersion.h
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBVersion : NSObject

@property (strong) NSNumber* versionID;
@property (strong) NSString* text;
@property (strong) NSDate* createdAt;

@end

NS_ASSUME_NONNULL_END
