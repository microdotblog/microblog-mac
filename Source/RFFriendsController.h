//
//  RFFriendsController.h
//  Snippets
//
//  Created by Manton Reece on 10/15/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RFFriendsController : NSViewController

@property (strong, nonatomic) IBOutlet NSTextField* headerField;
@property (strong, nonatomic) IBOutlet WebView* webView;

@property (strong, nonatomic) NSString* username;

- (instancetype) initWithUsername:(NSString *)username;

@end
