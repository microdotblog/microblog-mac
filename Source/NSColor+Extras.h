//
//  NSColor+Extras.h
//  Micro.blog
//
//  Created by Manton Reece on 2/12/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (Extras)

+ (NSColor *) mb_colorFromString:(NSString *)hexString;
- (NSString *) mb_hexString;

@end

NS_ASSUME_NONNULL_END
