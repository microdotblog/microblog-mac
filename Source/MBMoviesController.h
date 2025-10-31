//
//  MBMoviesController.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBMoviesController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (strong, nonatomic) NSArray* movies; // MBMovie

- (void) focusSearch;

@end

NS_ASSUME_NONNULL_END
