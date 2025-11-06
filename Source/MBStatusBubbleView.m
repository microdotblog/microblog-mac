//
//  MBStatusBubbleView.m
//  Micro.blog
//
//  Created by Manton Reece on 6/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBStatusBubbleView.h"

#import "RFConstants.h"
#import "NSAppearance+Extras.h"

@implementation MBStatusBubbleView

- (void) awakeFromNib
{
	if ([NSAppearance mb_isLiquidGlass]) {
		self.cornerRadius = 18;
	}
	else {
		self.cornerRadius = 7;
	}
	
	self.fillColor = [NSColor colorNamed:@"color_notification_background"];
}

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	CGRect r = NSRectToCGRect (self.bounds);
	if (self.isProcessingVideo) {
		if (r.size.width < 180) {
			self.statusMessageTextField.cell.title = @"Processing... 🍿";
		}
		else if (r.size.width < 210) {
			self.statusMessageTextField.cell.title = @"Processing video... 🍿";
		}
		else if (r.size.width < 280) {
			self.statusMessageTextField.cell.title = @"Processing uploaded video... 🍿";
		}
	}
	else {
		if (r.size.width < 180) {
			self.statusMessageTextField.cell.title = @"Publishing...";
		}
		else if (r.size.width < 210) {
			self.statusMessageTextField.cell.title = @"Publishing changes...";
		}
		else if (r.size.width < 280) {
			self.statusMessageTextField.cell.title = @"Publishing latest changes...";
		}
		else {
			self.statusMessageTextField.cell.title = @"Publishing latest changes to your blog...";
		}
	}

	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	
	CGPathRef path = CGPathCreateWithRoundedRect(r, self.cornerRadius, self.cornerRadius, NULL);

	[self.fillColor set];
	CGContextAddPath (context, path);
	CGContextFillPath (context);

	[[NSColor colorNamed:@"color_notification_border"] setStroke];
	CGContextSetLineWidth (context, 0.5);
	CGContextAddPath (context, path);
	CGContextStrokePath (context);
	
	CGPathRelease (path);
}

- (void) setProcessing:(BOOL)isProcessing
{
	self.isProcessingVideo = isProcessing;
	[self setNeedsDisplay:YES];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:kShowLogsNotification object:self];
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
