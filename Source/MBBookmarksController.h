//
//  MBBookmarksController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "MBSimpleTimelineController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBBookmarksController : MBSimpleTimelineController

@property (strong, nonatomic) IBOutlet NSBox* headerBox;
@property (strong, nonatomic) IBOutlet NSButton* currentTagCloseButton;
@property (strong, nonatomic) IBOutlet NSTextField* currentTagField;
@property (strong, nonatomic) IBOutlet NSPopUpButton* tagsButton;
@property (strong, nonatomic) IBOutlet WebView* webView;

@property (strong) NSArray* tags; // NSString
@property (assign, nonatomic, readonly) BOOL showingBookmarks;

- (void) refresh;
- (void) showHighlights;
- (void) focusContent;
- (void) bookmarksDidFinishLoading;

@end

NS_ASSUME_NONNULL_END
