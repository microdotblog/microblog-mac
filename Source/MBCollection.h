//
//  MBCollection.h
//  Micro.blog
//
//  Created by Manton Reece on 12/10/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBCollection : NSObject

@property (strong) NSString* name;
@property (strong) NSString* url;
@property (strong) NSNumber* uploadsCount;

@end

NS_ASSUME_NONNULL_END
