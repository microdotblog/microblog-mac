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

@interface MBVersionsController : NSWindowController

@property (strong, nonatomic) NSTableView* tableView;
@property (strong, nonatomic) NSProgressIndicator* progressSpinner;

@property (strong) MBNote* note;
@property (strong) NSArray* versions; // MBVersion

- (id) initWithNote:(MBNote *)note;

@end

NS_ASSUME_NONNULL_END
