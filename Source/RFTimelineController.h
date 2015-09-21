//
//  RFTimelineController.h
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface RFTimelineController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextView* textView;
@property (strong, nonatomic) IBOutlet WebView* webView;

@end
