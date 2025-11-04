//
//  MBAboutController.m
//  Micro.blog
//
//  Created by Manton Reece on 11/4/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBAboutController.h"

@implementation MBAboutController

- (id) init
{
	self = [super initWithWindowNibName:@"About"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupVersion];
}

- (void) setupVersion
{
	self.versionField.stringValue = @"1.0 (100)";
}

@end
