//
//  MBCrosspostCell.h
//  Micro.blog
//
//  Created by Manton Reece on 2/19/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBCrosspostCell : NSCollectionViewItem

@property (strong, nonatomic) IBOutlet NSButton* nameCheckbox;

@property (strong) NSString* uid;

@end

NS_ASSUME_NONNULL_END
