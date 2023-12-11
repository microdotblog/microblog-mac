//
//  MBNotesController.h
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBNotesController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (assign, nonatomic) BOOL isShowingPages;
@property (strong, nonatomic) NSArray* allNotes; // MBNote
@property (strong, nonatomic) NSArray* currentNotes; // MBNote

@end

NS_ASSUME_NONNULL_END
