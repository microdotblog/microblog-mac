//
//  RFRoundedImageView.m
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFRoundedImageView.h"

@implementation RFRoundedImageView

- (void) awakeFromNib
{
	self.layer.cornerRadius = self.bounds.size.width / 2.0;
}

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	if (self.image == nil) {
		CGRect r = NSRectToCGRect (self.bounds);
		CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
		
		CGPathRef path = CGPathCreateWithRoundedRect(r, r.size.width / 2.0, r.size.height / 2.0, NULL);
		CGContextAddPath (context, path);
		[[NSColor colorWithWhite:0.8 alpha:1.0] set];
		CGContextFillPath (context);
	}
}

- (void) loadFromURL:(NSString *)url
{
	NSImage* img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:url]];
	self.image = img;
}

@end
