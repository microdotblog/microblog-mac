//
//  MBBooksWindowController.h
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class RFBookshelf;

@interface MBBooksWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;

@property (strong, nonatomic) RFBookshelf* bookshelf;
@property (strong, nonatomic) NSArray* books; // RFBook

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf;

@end

NS_ASSUME_NONNULL_END
