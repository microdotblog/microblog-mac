//
//  RFRepliesController.h
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFRepliesController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSMenuItem* browserMenuItem;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (strong, nonatomic) NSArray* allReplies; // RFPost
@property (strong, nonatomic) NSArray* currentReplies; // RFPost

- (void) focusSearch;

@end

NS_ASSUME_NONNULL_END
