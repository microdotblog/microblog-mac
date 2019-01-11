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

- (id) initWithURL:(NSString *)photoURL
{
	self = [super initWithWindowNibName:@"PhotoZoom"];
	if (self) {
		self.photoURL = photoURL;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self downloadPhoto];
}

- (void) downloadPhoto
{
	[self startProgress];
	
	[UUHttpSession get:self.photoURL queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		NSData* d = response.rawResponse;
		RFDispatchMain (^{
			NSImage* img = [[NSImage alloc] initWithData:d];
			self.imageView.image = img;
			[self hideProgress];
		});
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

@end
