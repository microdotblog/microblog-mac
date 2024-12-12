//
//  RFAllUploadsController.h
//  Snippets
//
//  Created by Manton Reece on 7/13/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCollection;

@interface RFAllUploadsController : NSViewController <NSPopoverDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSCollectionView* collectionView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSButton* blogNameButton;
@property (strong, nonatomic) IBOutlet NSButton* collectionsButton;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (strong, nonatomic) NSArray* allPosts; // RFUpload
@property (strong, nonatomic, nullable) NSPopover* blogsMenuPopover;
@property (strong, nonatomic, nullable) MBCollection* selectedCollection;

- (void) focusSearch;
- (void) openSelectedItem;

@end

NS_ASSUME_NONNULL_END
