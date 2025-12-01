//
//  MBVideoZoomController.m
//  Micro.blog
//
//  Created by Manton Reece on 11/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVideoZoomController.h"

#import "RFConstants.h"

@implementation MBVideoZoomController

- (id) initWithURL:(NSString *)videoURL
{
	self = [super initWithWindowNibName:@"VideoZoom"];
	if (self) {
		self.videoURL = videoURL;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupVideo];
	[self updateTitle];
	
	self.window.delegate = self;
}

- (void) setupVideo
{
	NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Video" ofType:@"html"];
	NSString* template_html = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];
	
	NSString* html = [template_html stringByReplacingOccurrencesOfString:@"[URL]" withString:self.videoURL];

	[self.webView loadHTMLString:html baseURL:nil];
}

- (void) updateTitle
{
	NSURL* url = [NSURL URLWithString:self.videoURL];
	if (url) {
		self.window.title = url.host;
	}
}

- (BOOL) windowShouldClose:(NSWindow *)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPhotoWindowDidCloseNotification object:self];
	return YES;
}

- (void) downloadPhoto
{
	// override parent behavior to avoid trying to download the video
}

@end
