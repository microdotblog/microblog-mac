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

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupAppearance];
	}
	return self;
}

- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self setupAppearance];
	}
	return self;
}

- (void) awakeFromNib
{
	[super awakeFromNib];
}

- (void) setupAppearance
{
	if ([NSAppearance mb_isLiquidGlass]) {
		self.cornerRadius = 18;
	}
	else {
		self.cornerRadius = 7;
	}
	
	self.isWindowActive = YES;
	self.fillColor = [NSColor colorNamed:@"color_notification_background"];
	self.wantsLayer = YES;
	self.layer.shadowColor = [NSColor blackColor].CGColor;
	self.layer.shadowOpacity = 0.3;
	self.layer.shadowRadius = 6.0;
	self.layer.shadowOffset = CGSizeMake (0.0, -2.0);
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
		else {
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

	NSColor* border_color = self.isWindowActive ? [NSColor colorNamed:@"color_notification_border"] : [NSColor separatorColor];
	[border_color setStroke];
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

- (void) setWindowActive:(BOOL)isActive
{
	self.isWindowActive = isActive;
	if (isActive) {
		self.fillColor = [NSColor colorNamed:@"color_notification_background"];
		self.statusMessageTextField.textColor = [NSColor colorNamed:@"color_notification_text"];
		self.statusDetailTextField.textColor = [NSColor secondaryLabelColor];
	}
	else {
		self.fillColor = [NSColor windowBackgroundColor];
		self.statusMessageTextField.textColor = [NSColor disabledControlTextColor];
		self.statusDetailTextField.textColor = [NSColor disabledControlTextColor];
	}

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

- (NSView *) hitTest:(NSPoint)point
{
	NSView* hit_view = [super hitTest:point];
	if (hit_view) {
		return self;
	}
	else {
		return nil;
	}
}

- (BOOL) acceptsFirstMouse:(NSEvent *)event
{
	return YES;
}

- (void) mouseDown:(NSEvent *)event
{
}

- (void) mouseUp:(NSEvent *)event
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowLogsNotification object:self];
}

- (void) mouseEntered:(NSEvent *)event
{
	if (self.isWindowActive) {
		self.fillColor = [NSColor colorNamed:@"color_notification_background_hover"];
		[self setNeedsDisplay:YES];
	}
}

- (void) mouseExited:(NSEvent *)event
{
	if (self.isWindowActive) {
		self.fillColor = [NSColor colorNamed:@"color_notification_background"];
	}
	else {
		self.fillColor = [NSColor windowBackgroundColor];
	}
	[self setNeedsDisplay:YES];
}

@end
