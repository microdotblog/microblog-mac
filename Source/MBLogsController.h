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
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSSegmentedControl* segmentedControl;

@property (assign, nonatomic) BOOL isShowingErrors;
@property (strong, nonatomic) NSArray* allLogs; // MBLog
@property (strong, nonatomic) NSArray* errorLogs; // MBLog
@property (strong, nonatomic, nullable) NSDate* latestDate;
@property (strong, nonatomic) NSTimer* refreshTimer;

- (void) refresh;

@end

NS_ASSUME_NONNULL_END
