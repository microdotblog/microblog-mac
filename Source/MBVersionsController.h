//
//  MBVersionsController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class MBNote;

@interface MBVersionsController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSButton* restoreButton;

@property (strong) MBNote* note;
@property (strong) NSArray* versions; // MBVersion
@property (strong) NSString* secretKey;

- (id) initWithNote:(MBNote *)note secretKey:(NSString *)secretKey;

@end

NS_ASSUME_NONNULL_END
