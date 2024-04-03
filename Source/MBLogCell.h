//
//  MBLogCell.h
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBLog;

@interface MBLogCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* dateField;
@property (strong, nonatomic) IBOutlet NSTextField* messageField;

- (void) setupWithLog:(MBLog *)log;

@end

NS_ASSUME_NONNULL_END
