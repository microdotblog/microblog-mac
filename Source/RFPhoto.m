//
//  RFPhoto.m
//  Micro.blog
//
//  Created by Manton Reece on 3/22/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPhoto.h"

@implementation RFPhoto

- (id) initWithAsset:(PHAsset *)asset
{
	self = [super init];
	if (self) {
		self.asset = asset;
	}
	
	return self;
}

- (id) initWithThumbnail:(NSImage *)image
{
	self = [super init];
	if (self) {
		self.thumbnailImage = image;
	}
	
	return self;
}

@end
