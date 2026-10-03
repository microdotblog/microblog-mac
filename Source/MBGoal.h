//
//  MBGoal.h
//  Micro.blog
//
//  Created by Manton Reece on 8/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBGoal : NSObject

@property (strong) NSNumber* goalID;
@property (strong) NSNumber* year;
@property (strong) NSString* title;
@property (strong) NSString* text;
@property (strong) NSNumber* goalValue;
@property (strong) NSNumber* goalProgress;

@end

NS_ASSUME_NONNULL_END
