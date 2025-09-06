//
//  SAMKeychain+Helper.h
//  Micro.blog
//
//  Created by Manton Reece on 9/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SAMKeychain.h"

NS_ASSUME_NONNULL_BEGIN

@interface SAMKeychain (Helper)

+ (NSString *) mb_passwordForService:(NSString *)serviceName account:(NSString *)account;

@end

NS_ASSUME_NONNULL_END
