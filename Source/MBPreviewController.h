//
//  MBPreviewController.h
//  Micro.blog
//
//  Created by Manton Reece on 1/8/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBPreviewController : NSWindowController <WKNavigationDelegate>

@property (strong, nonatomic) IBOutlet WKWebView* webview;
@property (strong, nonatomic) IBOutlet NSButton* useThemeCheckbox;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;
@property (strong, nonatomic) IBOutlet NSTextField* warningField;

@property (strong, nonatomic) NSString* html;
@property (strong, nonatomic) NSMutableDictionary* cachedPhotoPaths;

+ (void) setCurrentPreviewTitle:(NSString *)title markdown:(NSString *)markdown photos:(NSArray *)photos;

@end

NS_ASSUME_NONNULL_END
