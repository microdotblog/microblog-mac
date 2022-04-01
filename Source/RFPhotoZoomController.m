//
//  RFPhotoZoomController.m
//  Snippets
//
//  Created by Manton Reece on 1/10/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPhotoZoomController.h"

#import "UUHttpSession.h"
#import "UUString.h"
#import "RFMacros.h"

@implementation RFPhotoZoomController

- (id) initWithURL:(NSString *)photoURL allowCopy:(BOOL)allowCopy
{
	self = [super initWithWindowNibName:@"PhotoZoom"];
	if (self) {
		self.photoURL = [self extractPhotoURL:photoURL];
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

- (NSString *) extractPhotoURL:(NSString *)url
{
	NSString* photo_url = url;
	
	if ([photo_url containsString:@"https://micro.blog/photos/"]) {
		NSString* partial_url = [photo_url stringByReplacingOccurrencesOfString:@"https://micro.blog/photos/" withString:@""];
		NSArray* pieces = [partial_url componentsSeparatedByString:@"/"];
		if ([pieces count] > 1) {
			NSString* size_component = [pieces firstObject];
			NSString* size_path = [NSString stringWithFormat:@"%@/", size_component];
			photo_url = [partial_url stringByReplacingOccurrencesOfString:size_path withString:@""];
			photo_url = [photo_url uuUrlDecoded];
		}
	}

	return photo_url;
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
	
	// sometimes NSImage.size is too small, check representations
	NSArray* reps = image.representations;
	for (NSImageRep* rep in reps) {
		if ((rep.pixelsWide > image.size.width) && (rep.pixelsHigh > image.size.height)) {
			NSSize full_size;
			full_size.width = rep.pixelsWide;
			full_size.height = rep.pixelsHigh;
			image.size = full_size;
			break;
		}
	}
	
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
	
	[self.window saveFrameUsingName:self.window.frameAutosaveName];
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
