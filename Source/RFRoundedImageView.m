//
//  RFRoundedImageView.m
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFRoundedImageView.h"

#import "RFMacros.h"
#import "RFUserCache.h"

@interface RFRoundedImageView ()

@property (strong, nonatomic) NSString* currentImageURL;

@end

@implementation RFRoundedImageView

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupRoundedLayer];
	}
	return self;
}

- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self setupRoundedLayer];
	}
	return self;
}

- (void) awakeFromNib
{
	[super awakeFromNib];
	[self setupRoundedLayer];
}

- (void) setupRoundedLayer
{
	self.wantsLayer = YES;
	self.layer.cornerRadius = self.bounds.size.width / 2.0;
}

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	if (self.image == nil) {
		CGRect r = NSRectToCGRect (self.bounds);
        CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
		
		CGPathRef path = CGPathCreateWithRoundedRect(r, r.size.width / 2.0, r.size.height / 2.0, NULL);
		CGContextAddPath (context, path);
		[[NSColor colorWithWhite:0.8 alpha:1.0] set];
		CGContextFillPath (context);
		
		CGPathRelease (path);
	}
}

- (void) loadFromURL:(NSString *)url
{
	[self loadFromURL:url completion:nil];
}

- (void) loadFromURL:(NSString *)url completion:(void (^)(void))handler
{
	self.currentImageURL = url;

	if (url.length == 0) {
		self.image = nil;
		if (handler) {
			handler();
		}
		return;
	}

	NSURL* image_url = [NSURL URLWithString:url];
	if (image_url == nil) {
		self.image = nil;
		if (handler) {
			handler();
		}
		return;
	}

	NSImage* image = [RFUserCache avatar:image_url completionHandler:^(NSImage* image) {
		if ([self.currentImageURL isEqualToString:url]) {
			self.image = image;
			self.layer.cornerRadius = self.bounds.size.width / 2.0;
			if (handler) {
				handler();
			}
		}
	}];

	if (image) {
		self.image = image;
		self.layer.cornerRadius = self.bounds.size.width / 2.0;
		if (handler) {
			handler();
		}
	}
}

@end
