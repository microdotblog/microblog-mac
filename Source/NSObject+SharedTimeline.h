//
//  NSObject+SharedTimeline.h
//  Micro.blog
//
//  Created by Manton Reece on 4/5/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (SharedTimeline)

- (void) setupCSS:(WebView *)webView;

@end

NS_ASSUME_NONNULL_END
