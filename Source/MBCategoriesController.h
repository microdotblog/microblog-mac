//
//  MBCategoriesController.h
//  Micro.blog
//
//  Created by Manton Reece on 4/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBCategory;

@interface MBCategoriesController : NSWindowController <NSURLSessionDownloadDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSButton* downloadButton;
@property (strong, nonatomic) IBOutlet NSTextField* sizeField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* modelProgressBar;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* downloadTopConstrant;
@property (strong, nonatomic) IBOutlet NSTableView* categoriesTable;
@property (strong, nonatomic) IBOutlet NSTableView* postsTable;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* workProgressBar;
@property (strong, nonatomic) IBOutlet NSTextField* numPostsField;
@property (strong, nonatomic) IBOutlet NSButton* autoCategorizeButton;
@property (strong, nonatomic) IBOutlet NSButton* updateCategoriesButton;

@property (strong, nonatomic) NSArray* categories; // MBCategory
@property (strong, nonatomic) NSArray* allPosts; // RFPost
@property (strong, nonatomic) NSArray* currentPosts; // RFPost
@property (strong, nonatomic) MBCategory* selectedCategory;
@property (strong, nullable) NSURLSession* downloadSession;
@property (strong, nullable) NSURLSessionDownloadTask* downloadTask;
@property (copy) NSString* modelDestinationPath;
@property (strong, nullable) NSTimer* sizeUpdateTimer;
@property (copy, nullable) NSString* latestDownloadedString;
@property (strong, nullable) NSDate* downloadStartDate;
@property (assign) int64_t expectedBytes;
@property (assign) NSTimeInterval remainingSeconds;

@end

NS_ASSUME_NONNULL_END
