//
//  MBVersionCell.h
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBVersion;

@interface MBVersionCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* textField;
@property (strong, nonatomic) IBOutlet NSTextField* dateField;

- (void) setupWithVersion:(MBVersion *)version;

@end

NS_ASSUME_NONNULL_END
