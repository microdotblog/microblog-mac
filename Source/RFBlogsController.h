//
//  RFBlogsController.h
//  Snippets
//
//  Created by Manton Reece on 3/21/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFBlogsController : NSViewController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

@property (strong, nonatomic) NSArray* destinations; // NSDictionary (uid, name)
@property (strong, nonatomic) NSTimer* progressTimer;

@end
