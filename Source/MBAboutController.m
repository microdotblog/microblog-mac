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
	NSBundle* bundle = [NSBundle mainBundle];
	NSString* version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString* build = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];

	if ((version.length > 0) && (build.length > 0)) {
		self.versionField.stringValue = [NSString stringWithFormat:@"Version %@ (%@)", version, build];
	}
	else {
		self.versionField.stringValue = @"";
	}
}

@end
