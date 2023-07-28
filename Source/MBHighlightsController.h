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
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong) NSArray* currentHighlights; // MBHighlight

@end

NS_ASSUME_NONNULL_END
