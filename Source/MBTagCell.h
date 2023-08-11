//
//  MBTagCell.h
//  Micro.blog
//
//  Created by Manton Reece on 8/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBTagCell : NSTableRowView

@property (strong, nonatomic) IBOutlet NSTextField* nameField;

- (void) setupWithName:(NSString *)tagName;

@end

NS_ASSUME_NONNULL_END
