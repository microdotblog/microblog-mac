//
//  RFConversationController.h
//  Snippets
//
//  Created by Manton Reece on 10/13/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "MBSimpleTimelineController.h"

@interface RFConversationController : MBSimpleTimelineController

@property (strong, nonatomic) IBOutlet NSTextField* headerField;
@property (strong, nonatomic) IBOutlet WebView* webView;

@property (strong, nonatomic) NSString* postID;

- (instancetype) initWithPostID:(NSString *)postID;

@end
