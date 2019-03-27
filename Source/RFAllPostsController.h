//
//  RFAllPostsController.h
//  Snippets
//
//  Created by Manton Reece on 3/23/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFAllPostsController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, NSPopoverDelegate>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSButton* blogNameButton;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (strong, nonatomic) NSArray* allPosts; // RFPost
@property (strong, nonatomic) NSArray* currentPosts; // RFPost
@property (strong, nonatomic) NSPopover* blogsMenuPopover;

- (void) fetchPosts;
- (void) focusSearch;

@end

NS_ASSUME_NONNULL_END
