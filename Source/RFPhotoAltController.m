//
//  RFPhotoAltController.m
//  Snippets
//
//  Created by Manton Reece on 1/12/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPhotoAltController.h"

#import "RFPhoto.h"

@implementation RFPhotoAltController

- (id) initWithPhoto:(RFPhoto *)photo
{
	self = [super initWithWindowNibName:@"PhotoAlt"];
	if (self) {
		self.photo = photo;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupPhotoThumbnail];
}

- (void) setupPhotoThumbnail
{
	self.imageView.image = self.photo.thumbnailImage;
}

- (IBAction) okPressed:(id)sender
{
}

- (IBAction) cancelPressed:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) removePressed:(id)sender
{
}

@end
