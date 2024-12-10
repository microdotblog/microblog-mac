//
//  MBCollectionCell.h
//  Micro.blog
//
//  Created by Manton Reece on 12/10/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCollection;

@interface MBCollectionCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* nameField;
@property (strong, nonatomic) IBOutlet NSTextField* uploadsField;

- (void) setupWithCollection:(MBCollection *)collection;

@end

NS_ASSUME_NONNULL_END
