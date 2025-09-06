//
//  MBBookNoteController.h
//  Micro.blog
//
//  Created by Manton Reece on 9/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBBook;
@class MBBookCoverView;
@class MBNotebook;

@interface MBBookNoteController : NSWindowController

@property (strong, nonatomic) IBOutlet NSBox* bookHeader;
@property (strong, nonatomic) IBOutlet MBBookCoverView* bookCoverView;
@property (strong, nonatomic) IBOutlet NSTextField* bookTitleField;
@property (strong, nonatomic) IBOutlet NSTextView* noteTextView;
@property (strong, nonatomic) IBOutlet NSButton* addButton;
@property (strong, nonatomic) IBOutlet NSButton* cancelButton;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) MBBook* book;
@property (strong, nonatomic) MBNotebook* notebook;

- (id) initWithBook:(MBBook *)book readingNotebook:(MBNotebook *)notebook;

@end

NS_ASSUME_NONNULL_END
