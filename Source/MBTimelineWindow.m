//
//  MBTimelineWindow.m
//  Micro.blog
//
//  Created by Manton Reece on 4/6/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBTimelineWindow.h"

#import "MBSimpleTimelineController.h"
#import "RFTimelineController.h"
#import <WebKit/WebKit.h>

@implementation MBTimelineWindow

- (void) sendEvent:(NSEvent *)event
{
	if (event.type == NSEventTypeKeyDown) {
		// if it's a web view, find next view controller
		// we'll handle some events ourselves
		NSString* class_s = NSStringFromClass([self.firstResponder class]);
		if ([class_s isEqualToString:@"WebHTMLView"]) {
			NSResponder* responder = self.firstResponder;
			while (responder != nil) {
				if ([responder isKindOfClass:[MBSimpleTimelineController class]] || [responder isKindOfClass:[RFTimelineController class]]) {
					NSUInteger c = [event keyCode];
					if (c == 126) { // up arrow
						[responder moveUp:nil];
						return;
					}
					else if (c == 125) { // down arrow
						[responder moveDown:nil];
						return;
					}
					else if (c == 36) { // return key
						[responder keyDown:event];
						return;
					}
				}
				
				responder = responder.nextResponder;
			}
		}
	}
	
	[super sendEvent:event];
}

@end
