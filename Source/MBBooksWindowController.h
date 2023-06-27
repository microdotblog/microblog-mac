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
@property (strong, nonatomic) IBOutlet NSMenu* contextMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem* browserMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem* deleteMenuItem;
@property (strong, nonatomic) IBOutlet NSMenuItem* deleteSeparatorItem;

@property (strong, nonatomic) RFBookshelf* bookshelf;
@property (strong, nonatomic) NSArray* allBooks; // MBBook
@property (strong, nonatomic) NSArray* currentBooks; // MBBook
@property (strong, nonatomic) NSArray* bookshelves; // RFBookshelf
@property (strong) NSMutableSet* coversQueue; // MBBook
@property (strong) NSTimer* coversTimer;
@property (assign) NSInteger coverDownloadsCount;

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf;
- (void) fetchBooks;

@end

NS_ASSUME_NONNULL_END
