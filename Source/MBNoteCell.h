//
//  MBNoteCell.h
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBNote;

@interface MBNoteCell : NSTableCellView

- (void) setupWithNote:(MBNote *)note;

@end

NS_ASSUME_NONNULL_END
