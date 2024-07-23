//
//  RFDiscoverController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/13/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "MBSimpleTimelineController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RFDiscoverController : MBSimpleTimelineController

@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSTextField* statusField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* spinner;
@property (strong, nonatomic) IBOutlet NSPopUpButton* popupButton;
@property (strong, nonatomic) IBOutlet NSView* headerView;
@property (strong, nonatomic) IBOutlet NSView* searchView;
@property (strong, nonatomic) IBOutlet NSSearchField* searchField;

@property (strong) NSString* selectedTopic;
@property (strong) NSMutableArray* tagmoji;

- (IBAction) showSearch:(nullable id)sender;
- (IBAction) hideSearch:(id)sender;

@end

NS_ASSUME_NONNULL_END
