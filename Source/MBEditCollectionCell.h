//
//  MBEditCollectionCell.h
//  Micro.blog
//
//  Created by Manton Reece on 12/12/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBEditCollectionCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* nameField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@end

NS_ASSUME_NONNULL_END
