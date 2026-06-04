//
//  MBCategoryCell.h
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCategory;

@interface MBCategoryCell : NSTableCellView

@property (strong, nonatomic) NSTextField* nameField;
@property (strong, nonatomic) NSTextField* countField;

- (void) setupWithCategory:(MBCategory *)category;

@end

NS_ASSUME_NONNULL_END
