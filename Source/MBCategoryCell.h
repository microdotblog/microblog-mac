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

@interface MBCategoryCell : NSTableRowView

@property (strong, nonatomic) NSTextField* nameField;
@property (strong, nonatomic) NSTextField* countField;
@property (strong, nonatomic) NSTextField* editField;

- (void) setupWithCategory:(MBCategory *)category;
- (void) setupForEditingWithCategory:(MBCategory *)category target:(id)target action:(SEL)action delegate:(id<NSTextFieldDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
