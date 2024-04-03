//
//  MBLogsController.h
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBLogsController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTableView* tableView;

@property (strong, nonatomic) NSArray* logs;

@end

NS_ASSUME_NONNULL_END
