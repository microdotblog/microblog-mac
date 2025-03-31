//
//  NSCollectionView+Extras.m
//  Micro.blog
//
//  Created by Manton Reece on 3/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "NSCollectionView+Extras.h"

@implementation NSCollectionView (Extras)

- (void) mb_safeReloadAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		[self reloadItemsAtIndexPaths:[NSSet setWithCollectionViewIndexPath:indexPath]];
	}
	@catch (NSException* e) {
	}
}

@end
