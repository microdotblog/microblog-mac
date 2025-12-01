//
//  MBVideoZoomController.m
//  Micro.blog
//
//  Created by Manton Reece on 11/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVideoZoomController.h"

@implementation MBVideoZoomController

- (id) initWithURL:(NSString *)photoURL altText:(NSString *)photoAlt allowCopy:(BOOL)allowCopy
{
	self = [super initWithWindowNibName:@"VideoZoom"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
}

@end
