//
//  RFMarkdownExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFMarkdownExportController.h"

@implementation RFMarkdownExportController

- (void) windowDidLoad
{
	[super windowDidLoad];
}

- (void) finishExport
{
	NSString* new_path = [self promptSave:@"Micro.blog export"];
	if (new_path) {
		[self copyItemAtPath:self.exportFolder toPath:new_path];
	}

	[self cleanupExport];
}

@end
