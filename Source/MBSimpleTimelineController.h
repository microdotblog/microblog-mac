//
//  MBSimpleTimelineController.h
//  Micro.blog
//
//  Created by Manton Reece on 4/4/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBSimpleTimelineController : NSViewController

@property (strong, nonatomic) IBOutlet WebView* webView;

@property (strong, nonatomic) NSString* url;
@property (strong, nonatomic) NSString* selectedPostID;

- (id) initWithURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
