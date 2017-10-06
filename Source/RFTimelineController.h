//
//  RFTimelineController.h
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class RFPostController;

@interface RFTimelineController : NSWindowController <NSSplitViewDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic) IBOutlet NSTableView* tableView;
@property (strong, nonatomic) IBOutlet NSSplitView* splitView;
@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSTextField* fullNameField;
@property (strong, nonatomic) IBOutlet NSTextField* usernameField;
@property (strong, nonatomic) IBOutlet NSImageView* profileImageView;

@property (strong, nonatomic) NSPopover* optionsPopover;
@property (strong, nonatomic) RFPostController* postController;

- (void) showOptionsMenuWithPostID:(NSString *)postID;
- (void) setSelected:(BOOL)isSelected withPostID:(NSString *)postID;

@end
