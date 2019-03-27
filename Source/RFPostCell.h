//
//  RFPostCell.h
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class RFPost;

@interface RFPostCell : NSTableRowView <NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextField* textField;
@property (strong, nonatomic) IBOutlet NSTextField* dateField;
@property (strong, nonatomic) IBOutlet NSTextField* draftField;
@property (strong, nonatomic) IBOutlet NSCollectionView* photosCollectionView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* textTopConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* dateTopConstraint;

@property (strong, nonatomic) NSArray* photos; // RFPhoto

- (void) setupWithPost:(RFPost *)post;

@end

NS_ASSUME_NONNULL_END
