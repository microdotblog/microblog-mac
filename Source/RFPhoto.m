//
//  RFPhoto.m
//  Micro.blog
//
//  Created by Manton Reece on 3/22/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPhoto.h"

@implementation RFPhoto

#if 0 // 10.13

- (id) initWithAsset:(PHAsset *)asset
{
	self = [super init];
	if (self) {
		self.asset = asset;
		self.altText = @"";
	}
	
	return self;
}

#endif

- (id) initWithThumbnail:(NSImage *)image
{
	self = [super init];
	if (self) {
		self.thumbnailImage = image;
		self.altText = @"";
	}
	
	return self;
}

- (NSData *) jpegData
{
	NSBitmapImageRep* rep = (NSBitmapImageRep *)self.thumbnailImage.representations.firstObject;
	NSData* d = [rep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{}];
	return d;
}

@end
