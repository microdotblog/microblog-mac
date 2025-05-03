//
//  MBEditCategoryCell.m
//  Micro.blog
//
//  Created by Manton Reece on 5/2/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBEditCategoryCell.h"

#import "MBCategory.h"

@implementation MBEditCategoryCell

- (void) setupWithCategory:(MBCategory *)category
{
	self.nameField.stringValue = category.name;
}

@end
