//
//  MBBlogImportController.h
//  Micro.blog
//
//  Created by Manton Reece on 12/23/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBlogImportController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (strong, nonatomic) IBOutlet NSTextField* summaryField;
@property (strong, nonatomic) IBOutlet NSTextField* hostnameField;
@property (strong, nonatomic) IBOutlet NSButton* importButton;
@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressBar;

@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSArray* posts; // RFPost
@property (strong, nonatomic) NSMutableArray* queuedPosts; // RFPost
@property (strong, nonatomic) NSString* unzippedPath;

- (instancetype) initWithFile:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
