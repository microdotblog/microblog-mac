//
//  RFDayOneExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFDayOneExportController.h"

#import "RFPost.h"
#import "RFSettings.h"
#import "NSAlert+Extras.h"
#import "HTMLParser.h"
#import "MMMarkdown.h"

static NSString* const kDayOneCommandLinePath = @"/usr/local/bin/dayone2";
static NSString* const kDayOneHelpPageURL = @"https://help.dayoneapp.com/en/articles/435871-command-line-interface-cli";

@interface RFDayOneExportController ()

@property (readwrite) RFAccount* account;

@end

@implementation RFDayOneExportController

- (instancetype) initWithAccount:(RFAccount *)account
{
    self = [super init];

    if (self) {
        self.account = account;
    }

    return self;
}

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

- (NSArray *) extractAttachmentURLs:(RFPost *)post
{
	NSMutableArray* urls = [NSMutableArray array];
	NSString* post_html = post.text;

	// if contains Markdown, convert post text to HTML to find these URLs
	if ([post_html containsString:@"]("]) {
		NSError* error = nil;
		post_html = [MMMarkdown HTMLStringWithMarkdown:post_html error:&error];
	}
	
	// parse for media tags
	NSError* error = nil;
	HTMLParser* p = [[HTMLParser alloc] initWithString:post_html error:&error];
	if (error == nil) {
		HTMLNode* body = [p body];

		NSArray* img_tags = [body findChildTags:@"img"];
		for (HTMLNode* img_tag in img_tags) {
			NSString* url = [img_tag getAttributeNamed:@"src"];
			if (url) {
				[urls addObject:url];
			}
		}

		NSArray* video_tags = [body findChildTags:@"video"];
		for (HTMLNode* video_tag in video_tags) {
			NSString* url = [video_tag getAttributeNamed:@"src"];
			if (url) {
				[urls addObject:url];
			}
		}

		NSArray* audio_tags = [body findChildTags:@"audio"];
		for (HTMLNode* audio_tag in audio_tags) {
			NSString* url = [audio_tag getAttributeNamed:@"src"];
			if (url) {
				[urls addObject:url];
			}
		}
	}
	
	return urls;
}

- (NSString *) rewriteText:(NSString *)text replacingAttachmentURL:(NSString *)findURL
{
	NSString* s = text;
	
	NSString* tag = [NSString stringWithFormat:@"<(.*) src=\"%@\"(.*)>", findURL];
	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:tag options:NSRegularExpressionCaseInsensitive error:NULL];
	s = [regex stringByReplacingMatchesInString:s options:0 range:NSMakeRange (0, text.length) withTemplate:@"[{attachment}]"];
	
	return s;
}

- (void) runDayOneForPost:(RFPost *)post withPath:(NSString *)path
{
	// NSTask with standard input of Markdown text
	// dayone2 -j "Test" -d "2021-05-01 14:00:00" -a "/path/to/upload.jpg" -- new
		
	NSError* error = nil;

	NSString* uploads_folder = [self.exportFolder stringByAppendingPathComponent:@"uploads"];
	[[NSFileManager defaultManager] createDirectoryAtPath:uploads_folder withIntermediateDirectories:YES attributes:nil error:&error];
	
	NSMutableArray* args = [NSMutableArray array];
	
	NSArray* photo_urls = [self extractAttachmentURLs:post];
	if (photo_urls.count > 0) {
		NSString* new_text = post.text;
		
		[args addObject:@"-a"];
		for (NSString* url in photo_urls) {
			NSURL* download_url = [NSURL URLWithString:url];
			NSString* year = [[download_url URLByDeletingLastPathComponent] lastPathComponent];
			NSString* year_folder = [uploads_folder stringByAppendingPathComponent:year];
			NSString* filename = [download_url lastPathComponent];
			NSString* file_path = [year_folder stringByAppendingPathComponent:filename];
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:file_path]) {
				new_text = [self rewriteText:new_text replacingAttachmentURL:url];
				[args addObject:file_path];
			}
		}
		
		[new_text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}

	NSFileHandle* f = [NSFileHandle fileHandleForReadingAtPath:path];
	NSString* d = [post.postedAt description];

    if (self.journalName) {
        [args addObjectsFromArray:@[@"-j", self.journalName]];
    }

	[args addObjectsFromArray:@[@"-d", d, @"--", @"new"]];
	
	NSTask* t = [[NSTask alloc] init];
	t.launchPath = kDayOneCommandLinePath;
	t.arguments = args;
	t.standardInput = f;
	
	[t launch];
	[t waitUntilExit];
}

- (NSString *) journalName
{
    NSString* s = [RFSettings stringForKey:kDayOneJournalName account:self.account];

    if (s != nil && s.length > 0) {
        return s;
    } else {
        return nil;
    }
}

- (NSString *) writePost:(RFPost *)post
{
	NSString* path = [self writePost:post includeFrontmatter:NO];
	[self runDayOneForPost:post withPath:path];
	return path;
}

- (void) finishExport
{
	[self cleanupExport];
}

@end
