//
//  RFCategoryCell.h
//  Snippets
//
//  Created by Manton Reece on 1/28/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFCategoryCell : NSCollectionViewItem

@property (strong, nonatomic) IBOutlet NSButton* categoryCheckbox;

@end

NS_ASSUME_NONNULL_END
