//
//  NSAppearance+Extras.h
//  Snippets
//
//  Created by Manton Reece on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAppearance (Extras)

+ (BOOL) rf_isDarkMode;
- (BOOL) rf_isDarkMode;
+ (BOOL) mb_isLiquidGlass;

@end

NS_ASSUME_NONNULL_END
