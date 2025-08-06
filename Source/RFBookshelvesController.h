//
//  RFBookshelvesController.h
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MBGoal.h"

NS_ASSUME_NONNULL_BEGIN

@interface RFBookshelvesController : NSViewController

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSPopUpButton* goalsPopup;
@property (strong, nonatomic) IBOutlet NSTextField* goalSummaryField;
@property (strong, nonatomic) IBOutlet NSButton* editButton;

@property (strong, nonatomic) NSArray* bookshelves; // RFBookshelf
@property (strong, nonatomic) NSArray* goals; // MBGoal
@property (strong, nonatomic) MBGoal* selectedGoal;

+ (NSAttributedString *) attributedTitleForGoal:(MBGoal *)goal;

@end

NS_ASSUME_NONNULL_END
