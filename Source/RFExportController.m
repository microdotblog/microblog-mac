//
//  RFExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFExportController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "RFSettings.h"
#import "RFPost.h"
#import "UUDate.h"

@implementation RFExportController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Export"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupWindow];
	[self setupProgress];
	[self downloadPostsInBackgroundWithOffset:0];
}

- (void) setupWindow
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationName];
	if (destination_uid != nil) {
		NSString* s = [NSString stringWithFormat:@"Export for %@", destination_uid];
		[self.window setTitle:s];
	}
}

- (void) setupProgress
{
	[self.progressBar setIndeterminate:YES];
	[self.progressBar startAnimation:nil];
}

- (void) downloadPostsInBackgroundWithOffset:(NSInteger)offset
{
	[self performSelectorInBackground:@selector(downloadPosts:) withObject:@(offset)];
}

- (void) downloadPosts:(NSNumber *)offset
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSInteger limit = 200;
	
	NSDictionary* args;
	NSString* channel = @"default";
	
	args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"mp-channel": channel,
		@"limit": @(limit),
		@"offset": offset
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([offset integerValue] > 0) {
			NSString* s = [NSString stringWithFormat:@"Downloading posts (%@)...", offset];
			RFDispatchMainAsync (^{
				[self.statusField setStringValue:s];
			});
		}
		
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFPost* post = [[RFPost alloc] init];
				NSDictionary* props = [item objectForKey:@"properties"];
				post.postID = [[props objectForKey:@"uid"] firstObject];
				post.title = [[props objectForKey:@"name"] firstObject];
				post.text = [[props objectForKey:@"content"] firstObject];
				post.url = [[props objectForKey:@"url"] firstObject];

				NSString* date_s = [[props objectForKey:@"published"] firstObject];
				post.postedAt = [NSDate uuDateFromRfc3339String:date_s];

				NSString* status = [[props objectForKey:@"post-status"] firstObject];
				post.isDraft = [status isEqualToString:@"draft"];
				post.channel = channel;
				
				post.categories = @[];
				if ([[props objectForKey:@"category"] count] > 0) {
					post.categories = [props objectForKey:@"category"];
				}

				[new_posts addObject:post];
				
				[self writePost:post includeFrontmatter:NO];
			}
			
			// wait a second so we don't hit the server too much
			[NSThread sleepForTimeInterval:1];
			
			RFDispatchMainAsync (^{
				if (new_posts.count == 0) {
					[self.progressBar stopAnimation:nil];
					[self.statusField setStringValue:@"Finished export."];
					[self.cancelButton setTitle:@"Reveal Folder"];
					[self.cancelButton setAction:@selector(revealFolder:)];
				}
				else {
					NSInteger new_offset = [offset integerValue] + limit;
					[self downloadPostsInBackgroundWithOffset:new_offset];
				}
			});
		}
	}];
}

- (void) writePost:(RFPost *)post includeFrontmatter:(BOOL)includeFrontmatter
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains (NSDownloadsDirectory, NSUserDomainMask, YES);
	NSString* downloads_folder = [paths firstObject];

	NSString* folder_name = @"Micro.blog export";
	NSString* destination_name = [RFSettings stringForKey:kCurrentDestinationName];
	if (destination_name != nil) {
		folder_name = [NSString stringWithFormat:@"Micro.blog export (%@)", destination_name];
	}
	
	NSError* error = nil;

	NSString* export_folder = [downloads_folder stringByAppendingPathComponent:folder_name];
	[[NSFileManager defaultManager] createDirectoryAtPath:export_folder withIntermediateDirectories:YES attributes:nil error:&error];

	self.exportFolder = export_folder;
	
	NSDateComponents* components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:post.postedAt];

	NSString* date_name = [NSString stringWithFormat:@"%ld", (long)components.year];
	NSString* date_folder = [export_folder stringByAppendingPathComponent:date_name];
	[[NSFileManager defaultManager] createDirectoryAtPath:date_folder withIntermediateDirectories:YES attributes:nil error:&error];
	
	NSString* file_content = post.text;
	
	if (includeFrontmatter) {
	}
	
	NSString* filename = [NSString stringWithFormat:@"%@.md", post.postID];
	NSString* markdown_path = [date_folder stringByAppendingPathComponent:filename];
	[file_content writeToFile:markdown_path atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (IBAction) cancel:(id)sender
{
	[self.window performClose:nil];
}

- (IBAction) revealFolder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:self.exportFolder withApplication:@"Finder"];
}

@end
