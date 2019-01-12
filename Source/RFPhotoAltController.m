//
//  RFPhotoAltController.m
//  Snippets
//
//  Created by Manton Reece on 1/12/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPhotoAltController.h"

#import "RFPhoto.h"
#import "RFHighlightingTextStorage.h"
#import "RFConstants.h"

@implementation RFPhotoAltController

- (id) initWithPhoto:(RFPhoto *)photo atIndex:(NSIndexPath *)indexPath
{
	self = [super initWithWindowNibName:@"PhotoAlt"];
	if (self) {
		self.photo = photo;
		self.indexPath = indexPath;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupPhotoThumbnail];
	[self setupText];
}

- (void) setupPhotoThumbnail
{
	self.imageView.image = self.photo.thumbnailImage;
}

- (void) setupText
{
//	NSFont* normal_font = [NSFont fontWithName:@"Avenir-Book" size:kDefaultFontSize];
	NSFont* system_font = [NSFont systemFontOfSize:14];
	self.descriptionField.font = system_font;
	self.descriptionField.delegate = self;
}

- (IBAction) okPressed:(id)sender
{
	self.photo.altText = [self.descriptionField string];
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) cancelPressed:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) removePressed:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kRemoveAttachedPhotoNotification object:self userInfo:@{ kRemoveAttachedPhotoIndexPath: self.indexPath }];
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	if ([replacementString isEqualToString:@"\n"]) {
		[self.okButton performClick:nil];
		return NO;
	}
	else {
		return YES;
	}
}

@end
