//
//  MBVideoZoomController.m
//  Micro.blog
//
//  Created by Manton Reece on 11/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVideoZoomController.h"

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
	
	NSURL* url = [NSURL URLWithString:self.videoURL];
	if (url) {
		NSURLRequest* request = [NSURLRequest requestWithURL:url];
		[self.webView loadRequest:request];
	}
}

- (void) downloadPhoto
{
	// override parent behavior to avoid trying to download the video
}

@end
