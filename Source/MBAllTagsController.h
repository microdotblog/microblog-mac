//
//  MBAllTagsController.h
//  Micro.blog
//
//  Created by Manton Reece on 8/10/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBAllTagsController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;

@property (strong, nonatomic) NSArray* currentTags; // NSString

@end

NS_ASSUME_NONNULL_END
