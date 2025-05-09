//
//  MBBookmark.h
//  Micro.blog
//
//  Created by Manton Reece on 7/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBookmark : NSObject

@property (strong) NSNumber* bookmarkID;
@property (strong) NSString* flatTags;

@end

NS_ASSUME_NONNULL_END
