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

@property (strong, nonatomic) IBOutlet WebView* webView;

@end

NS_ASSUME_NONNULL_END
