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
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;
@property (strong, nonatomic) IBOutlet NSTextField* booksCountField;

@property (strong, nonatomic) RFBookshelf* bookshelf;
@property (strong, nonatomic) NSArray* allBooks; // RFBook
@property (strong, nonatomic) NSArray* currentBooks; // RFBook

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf;

@end

NS_ASSUME_NONNULL_END
