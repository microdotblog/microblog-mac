//
//  RFAllUploadsController.h
//  Snippets
//
//  Created by Manton Reece on 7/13/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFAllUploadsController : NSViewController <NSPopoverDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSCollectionView* collectionView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* uploadProgressBar;
@property (strong, nonatomic) IBOutlet NSButton* blogNameButton;
@property (strong, nonatomic) IBOutlet NSButton* collectionsButton;

@property (strong, nonatomic) NSArray* allPosts; // RFUpload
@property (strong, nonatomic, nullable) NSPopover* blogsMenuPopover;

- (void) openSelectedItem;

@end

NS_ASSUME_NONNULL_END
