//
//  MBVideoZoomController.h
//  Micro.blog
//
//  Created by Manton Reece on 11/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "RFPhotoZoomController.h"
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBVideoZoomController : RFPhotoZoomController

@property (strong, nonatomic) IBOutlet WKWebView* webView;

@property (strong, nonatomic) NSString* videoURL;

- (id) initWithURL:(NSString *)videoURL;

@end

NS_ASSUME_NONNULL_END
