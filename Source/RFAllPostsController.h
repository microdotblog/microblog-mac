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

@property (assign, nonatomic) BOOL isShowingPages;
@property (strong, nonatomic) NSArray* allPosts; // RFPost
@property (strong, nonatomic) NSArray* currentPosts; // RFPost
@property (strong, nonatomic) NSPopover* blogsMenuPopover;

- (id) initShowingPages:(BOOL)isShowingPages;
- (void) fetchPosts;
- (void) focusSearch;
- (void) openRow:(id)sender;

@end

NS_ASSUME_NONNULL_END
