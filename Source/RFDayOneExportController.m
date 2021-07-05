//
//  RFDayOneExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFDayOneExportController.h"

#import "RFPost.h"

@implementation RFDayOneExportController

- (void) windowDidLoad
{
	[super windowDidLoad];
}

- (void) checkForDayOne
{
	// see if "dayone2" command line tool is installed
	// otherwise direct user to the Day One help page:
	// https://help.dayoneapp.com/en/articles/435871-command-line-interface-cli
}

- (void) runDayOneForPost:(RFPost *)post
{
	// NSTask with standard input of Markdown text
	// dayone2 -j "Test" -d "2021-05-01 14:00:00" -- new
}

- (void) writePost:(RFPost *)post
{
	[self writePost:post includeFrontmatter:NO];
}

@end
