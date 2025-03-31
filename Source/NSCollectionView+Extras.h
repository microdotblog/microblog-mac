//
//  NSCollectionView+Extras.h
//  Micro.blog
//
//  Created by Manton Reece on 3/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionView (Extras)

- (void) mb_safeReloadAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
