//
//  MBEditCategoryCell.h
//  Micro.blog
//
//  Created by Manton Reece on 5/2/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCategory;

@interface MBEditCategoryCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* nameField;

- (void) setupWithCategory:(MBCategory *)category;

@end

NS_ASSUME_NONNULL_END
