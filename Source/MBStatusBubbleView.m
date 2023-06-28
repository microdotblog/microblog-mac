//
//  MBStatusBubbleView.m
//  Micro.blog
//
//  Created by Manton Reece on 6/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBStatusBubbleView.h"

@implementation MBStatusBubbleView

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	CGRect r = NSRectToCGRect (self.bounds);
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	
	CGPathRef path = CGPathCreateWithRoundedRect(r, 7.0, 7.0, NULL);

	[[NSColor colorNamed:@"color_notification_background"] set];
	CGContextAddPath (context, path);
	CGContextFillPath (context);

	[[NSColor colorNamed:@"color_notification_border"] setStroke];
	CGContextSetLineWidth (context, 0.5);
	CGContextAddPath (context, path);
	CGContextStrokePath (context);
}

@end
