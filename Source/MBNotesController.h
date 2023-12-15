//
//  MBNotesController.h
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBNote;
@class MBNotesKeyController;

@interface MBNotesController : NSViewController <NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;
@property (strong, nonatomic) IBOutlet NSTextView* detailTextView;

@property (strong, nonatomic) NSString* secretKey;
@property (strong, nonatomic) NSArray* allNotes; // MBNote
@property (strong, nonatomic) NSArray* currentNotes; // MBNote
@property (strong, nonatomic) NSMutableSet* editedNotes; // MBNote
@property (strong, nonatomic, nullable) MBNote* selectedNote;
@property (strong, nonatomic, nullable) MBNotesKeyController* notesKeyController;

- (void) fetchNotes;
- (void) focusSearch;

@end

NS_ASSUME_NONNULL_END
