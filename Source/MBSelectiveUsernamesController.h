//
//  MBSelectiveUsernamesController.h
//  Micro.blog
//
//  Created by Manton Reece on 6/16/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBSelectiveUsernamesController : NSObject <NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

@property (nonatomic, copy) NSArray<NSString *>* usernames;
@property (nonatomic, weak) NSCollectionView* collectionView;

- (instancetype) initWithCollectionView:(NSCollectionView *)collectionView;

@end

NS_ASSUME_NONNULL_END
