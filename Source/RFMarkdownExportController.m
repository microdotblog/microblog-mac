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
	NSError* error = nil;
	
	NSString* new_path = [self promptSave:@"Micro.blog export"];
	if (new_path) {
		[[NSFileManager defaultManager] copyItemAtPath:self.exportFolder toPath:new_path error:&error];
	}

	[self cleanupExport];
}

@end
