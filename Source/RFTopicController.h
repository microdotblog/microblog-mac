//
//  RFTopicController.h
//  Snippets
//
//  Created by Manton Reece on 1/8/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RFTopicController : NSViewController

@property (strong, nonatomic) IBOutlet NSTextField* headerField;
@property (strong, nonatomic) IBOutlet WebView* webView;
@property (strong, nonatomic) IBOutlet NSTextField* topicField;

@property (strong, nonatomic) NSString* topic;

- (instancetype) initWithTopic:(NSString *)topic;

@end
