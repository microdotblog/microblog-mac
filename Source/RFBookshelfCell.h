//
//  RFBookshelfCell.h
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFBookshelf;

NS_ASSUME_NONNULL_BEGIN

@interface RFBookshelfCell : NSTableRowView

@property (strong) IBOutlet NSTextField* titleField;
@property (strong) IBOutlet NSCollectionView* collectionView;

@property (strong, nonatomic) RFBookshelf* bookshelf;
@property (strong, nonatomic) NSArray* books; // RFBook

- (void) setupWithBookshelf:(RFBookshelf *)bookshelf;

@end

NS_ASSUME_NONNULL_END
