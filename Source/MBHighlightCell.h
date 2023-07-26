//
//  MBHighlightCell.h
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MBHighlight;

NS_ASSUME_NONNULL_BEGIN

@interface MBHighlightCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* selectionTextField;
@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextField* dateField;

@property (strong) MBHighlight* highlight;
	
- (void) setupWithHighlight:(MBHighlight *)highlight;

@end

NS_ASSUME_NONNULL_END
