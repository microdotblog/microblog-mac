//
//  RFPostCell.h
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPostCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextField* textField;
@property (strong, nonatomic) IBOutlet NSTextField* dateField;
@property (strong, nonatomic) IBOutlet NSTextField* draftField;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* textTopConstraint;

@end

NS_ASSUME_NONNULL_END
