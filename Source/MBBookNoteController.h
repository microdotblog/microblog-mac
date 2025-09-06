//
//  MBBookNoteController.h
//  Micro.blog
//
//  Created by Manton Reece on 9/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBookNoteController : NSWindowController

@property (strong, nonatomic) IBOutlet NSButton* addButton;
@property (strong, nonatomic) IBOutlet NSButton* cancelButton;

@end

NS_ASSUME_NONNULL_END
