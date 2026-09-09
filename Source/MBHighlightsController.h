//
//  MBHighlightsController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBHighlightsController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSMenuItem* browserMenuItem;
@property (assign, nonatomic, readonly) BOOL loading;
@property (copy, nonatomic, nullable) void (^loadingDidChange)(void);

@property (strong) NSArray* currentHighlights; // MBHighlight

- (void) fetchHighlights;

@end

NS_ASSUME_NONNULL_END
