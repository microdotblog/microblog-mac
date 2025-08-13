//
//  NSLocale+Format.h
//  Micro.blog
//
//  Created by Manton Reece on 8/13/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSLocale (Format)

// get formatting info for locale
- (NSDictionary *) mb_localeInfo;
+ (NSDictionary *) mb_localeInfoAutoupdating;

// individual helpers
- (NSString *) mb_hourCycle; // "h12", "h24"
- (NSString *) mb_dateOrder; // "MDY", "DMY", or "YMD"
- (NSString *) mb_dateSeparator;

@end

NS_ASSUME_NONNULL_END
