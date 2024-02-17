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

@interface MBNoteCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* textView;
@property (strong, nonatomic) IBOutlet NSView* sharedView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* sharedHeightConstraint;

- (void) setupWithNote:(MBNote *)note;

@end

NS_ASSUME_NONNULL_END
