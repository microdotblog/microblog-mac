//
//  MBStatusBubbleView.m
//  Micro.blog
//
//  Created by Manton Reece on 6/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBStatusBubbleView.h"

@implementation MBStatusBubbleView

- (void) awakeFromNib
{
	self.fillColor = [NSColor colorNamed:@"color_notification_background"];
}

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

    if (dirtyRect.size.width < 200) {
        self.statusMessageTextField.cell.title = @"Publishing changes...";
    } else {
        self.statusMessageTextField.cell.title = @"Publishing latest changes to your blog...";
    }

	CGRect r = NSRectToCGRect (self.bounds);
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	
	CGPathRef path = CGPathCreateWithRoundedRect(r, 7.0, 7.0, NULL);

	[self.fillColor set];
	CGContextAddPath (context, path);
	CGContextFillPath (context);

	[[NSColor colorNamed:@"color_notification_border"] setStroke];
	CGContextSetLineWidth (context, 0.5);
	CGContextAddPath (context, path);
	CGContextStrokePath (context);
	
	CGPathRelease (path);
}

- (void) updateTrackingAreas
{
	if (self.customTrackingArea) {
		[self removeTrackingArea:self.customTrackingArea];
	}

	self.customTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingActiveInKeyWindow | NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
	[self addTrackingArea:self.customTrackingArea];
}

- (void) mouseUp:(NSEvent *)event
{
	// only allow clicks if the parent isn't dimmed or hidden
	if (self.superview.alphaValue == 1.0) {
		NSURL* url = [NSURL URLWithString:@"https://micro.blog/account/logs"];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (void) mouseEntered:(NSEvent *)event
{
	self.fillColor = [NSColor colorNamed:@"color_notification_background_hover"];
	[self setNeedsDisplay:YES];
}

- (void) mouseExited:(NSEvent *)event
{
	self.fillColor = [NSColor colorNamed:@"color_notification_background"];
	[self setNeedsDisplay:YES];
}

@end
