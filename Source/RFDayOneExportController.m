//
//  RFDayOneExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFDayOneExportController.h"

#import "RFPost.h"
#import "NSAlert+Extras.h"

static NSString* const kDayOneCommandLinePath = @"/usr/local/bin/dayone2";
static NSString* const kDayOneHelpPageURL = @"https://help.dayoneapp.com/en/articles/435871-command-line-interface-cli";

@implementation RFDayOneExportController

- (void) windowDidLoad
{
	[super windowDidLoad];
}

+ (BOOL) checkForDayOne
{
	BOOL found = YES;
	
	// see if "dayone2" command line tool is installed
	// otherwise direct user to the Day One help page
	
	@try {
		[NSTask launchedTaskWithLaunchPath:kDayOneCommandLinePath arguments:@[]];
	}
	@catch (NSException* e) {
		found = NO;
		[NSAlert rf_showTwoButtonAlert:@"Day One Not Found" message:@"Micro.blog could not locate the dayone2 command-line tool, which is required for exporting to Day One. See the Day One help for details." okButton:@"Show Help" cancelButton:@"Cancel" completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kDayOneHelpPageURL]];
			}
		}];
	}
	
	return found;
}

- (void) runDayOneForPost:(RFPost *)post withPath:(NSString *)path
{
	// NSTask with standard input of Markdown text
	// dayone2 -j "Test" -d "2021-05-01 14:00:00" -a "/path/to/upload.jpg" -- new
	
	NSFileHandle* f = [NSFileHandle fileHandleForReadingAtPath:path];
	NSString* d = [post.postedAt description];
	
	NSTask* t = [[NSTask alloc] init];
	t.launchPath = kDayOneCommandLinePath;
	t.arguments = @[ @"-d", d, @"--", @"new"];
	t.standardInput = f;
	
	[t launch];
	[t waitUntilExit];
}

- (NSString *) writePost:(RFPost *)post
{
	NSString* path = [self writePost:post includeFrontmatter:NO];
	[self runDayOneForPost:post withPath:path];
	return path;
}

@end
