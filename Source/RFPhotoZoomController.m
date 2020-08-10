//
//  RFPhotoZoomController.m
//  Snippets
//
//  Created by Manton Reece on 1/10/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPhotoZoomController.h"

#import "UUHttpSession.h"
#import "RFMacros.h"

@implementation RFPhotoZoomController

- (id) initWithURL:(NSString *)photoURL allowCopy:(BOOL)allowCopy
{
	self = [super initWithWindowNibName:@"PhotoZoom"];
	if (self) {
		self.photoURL = photoURL;
		self.isAllowCopy = allowCopy;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self updateTitle];
	[self downloadPhoto];
	
	self.htmlCopyButton.hidden = !self.isAllowCopy;
	self.htmlCopyButton.layer.opacity = 0.0;
}

- (void) downloadPhoto
{
	[self startProgress];
	
	[UUHttpSession get:self.photoURL queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		NSData* d = response.rawResponse;
		RFDispatchMain (^{
			NSImage* img = [[NSImage alloc] initWithData:d];
			if (img) {
				[self updateWithImage:img];
			}
			[self hideProgress];
		});
	}];
}

- (void) updateTitle
{
	NSURL* url = [NSURL URLWithString:self.photoURL];
	if (url) {
		self.window.title = url.host;
	}
}

- (void) updateWithImage:(NSImage *)image
{
	self.imageView.hidden = YES;
	self.imageView.image = image;
	self.window.contentAspectRatio = image.size;

	NSRect screen_r = [NSScreen mainScreen].visibleFrame;

	CGSize content_size;
	content_size.width = 600;
	content_size.height = content_size.width / image.size.width * image.size.height;
	
	if (content_size.height > screen_r.size.height) {
		// don't let the window be bigger than the screen
		const CGFloat kExtraPadding = 50;
		content_size.height = screen_r.size.height - kExtraPadding;
		content_size.width = content_size.height / image.size.height * image.size.width;
	}
	
	CGRect content_r = [self.window contentRectForFrameRect:self.window.frame];
	CGRect window_r = self.window.frame;
	CGFloat titlebar_height = window_r.size.height - content_r.size.height;

	CGRect r = self.window.frame;
	r.origin.y = r.origin.y + (r.size.height - content_size.height) - titlebar_height;
	r.size = CGSizeMake (content_size.width, content_size.height + titlebar_height);
	[self.window setFrame:r display:YES animate:YES];
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		context.duration = 0.3;
		[self.imageView animator].hidden = NO;
		self.htmlCopyButton.layer.opacity = 0.7;
	}];
}

- (void) startProgress
{
	[self.spinner startAnimation:nil];
}

- (void) hideProgress
{
	[self.spinner stopAnimation:nil];
}

- (IBAction) copyHTML:(id)sender
{
	NSString* s = [NSString stringWithFormat:@"<img src=\"%@\" />", self.photoURL];

	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:s forType:NSPasteboardTypeString];
	
	[self.htmlCopyButton setTitle:@"Copied"];
}

@end
