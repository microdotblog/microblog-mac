//
//  MBCollectionCell.m
//  Micro.blog
//
//  Created by Manton Reece on 12/10/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBCollectionCell.h"

#import "MBCollection.h"

@implementation MBCollectionCell

- (void) setupWithCollection:(MBCollection *)collection
{
	self.nameField.stringValue = collection.name;
	self.uploadsField.stringValue = collection.uploadsCount.stringValue;
}

@end
