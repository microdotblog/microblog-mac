//
//  MBCategoriesController.h
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCategory;

@interface MBCategoriesController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate, NSTextFieldDelegate>

@property (strong, nonatomic) NSTableView* categoriesTableView;
@property (strong, nonatomic) NSTableView* postsTableView;
@property (strong, nonatomic) NSSplitView* splitView;
@property (strong, nonatomic) NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) NSButton* blogNameButton;
@property (strong, nonatomic) NSMenu* categoryContextMenu;
@property (strong, nonatomic) NSMenu* postContextMenu;

@property (strong, nonatomic) NSArray* categories; // MBCategory
@property (strong, nonatomic) NSArray* currentPosts; // RFPost
@property (strong, nonatomic, nullable) MBCategory* selectedCategory;

- (void) fetchCategories;
- (void) fetchPosts;
- (void) openRow:(id)sender;

@end

NS_ASSUME_NONNULL_END
