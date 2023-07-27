//
//  MBBookmarksController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBookmarksController : NSViewController

@property (strong, nonatomic) IBOutlet NSButton* highlightsCountButton;
@property (strong, nonatomic) IBOutlet NSPopUpButton* tagsButton;
@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* highlightsTopConstraint;

@property (strong) NSNumber* highlightsCount;
@property (strong) NSArray* tags; // NSString

@end

NS_ASSUME_NONNULL_END
