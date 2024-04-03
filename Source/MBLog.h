//
//  MBLog.h
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBLog : NSObject

@property (strong) NSDate* date;
@property (strong) NSString* message;

@end

NS_ASSUME_NONNULL_END
