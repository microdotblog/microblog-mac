//
//  MBCategoriesController.h
//  Micro.blog
//
//  Created by Manton Reece on 4/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBCategoriesController : NSWindowController <NSURLSessionDownloadDelegate>

@property (strong, nonatomic) IBOutlet NSButton* downloadButton;
@property (strong, nonatomic) IBOutlet NSTextField* sizeField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressBar;

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
