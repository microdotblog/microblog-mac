//
//  MBCollectionsController.h
//  Micro.blog
//
//  Created by Manton Reece on 12/10/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBCollectionsController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSArray* collections; // MBCollection

- (void) refresh;

@end

NS_ASSUME_NONNULL_END
