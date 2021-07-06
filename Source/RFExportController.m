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
#import "RFUpload.h"
#import "UUDate.h"
#import "NSString+Extras.h"

// How the export works:
// * Page through all the posts. As we download them, we write out the Markdown to ~/Downloads.
// * Page through all the uploads. We store the URLs in self.queuedUploads.
// * Download all the photos and other uploads.
// Subclasses like RFDayOneExportController can take further action on the downloaded files.

@implementation RFExportController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Export"];
	if (self) {
		self.queuedUploads = [NSMutableArray array];
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
				
				[self writePost:post];
			}
			
			// wait a second so we don't hit the server too much
			[NSThread sleepForTimeInterval:1];
			
			RFDispatchMainAsync (^{
				if (new_posts.count == 0) {
					[self.statusField setStringValue:@"Downloading uploaded files..."];
					[self downloadUploadsInBackgroundWithOffset:0];
				}
				else {
					NSInteger new_offset = [offset integerValue] + limit;
					[self downloadPostsInBackgroundWithOffset:new_offset];
				}
			});
		}
	}];
}

- (void) downloadUploadsInBackgroundWithOffset:(NSInteger)offset
{
	[self performSelectorInBackground:@selector(downloadUploads:) withObject:@(offset)];
}

- (void) downloadUploads:(NSNumber *)offset
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSInteger limit = 200;

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"limit": @(limit),
		@"offset": offset
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFUpload* upload = [[RFUpload alloc] init];
				upload.url = [item objectForKey:@"url"];

				upload.width = [[item objectForKey:@"width"] integerValue];
				upload.height = [[item objectForKey:@"height"] integerValue];

				NSString* date_s = [item objectForKey:@"published"];
				upload.createdAt = [NSDate uuDateFromRfc3339String:date_s];

				[new_posts addObject:upload];
			}
			
			// wait a second so we don't hit the server too much
			[NSThread sleepForTimeInterval:1];

			RFDispatchMainAsync (^{
				if (new_posts.count == 0) {
					self.totalUploads = self.queuedUploads.count;
					[self.progressBar setIndeterminate:NO];
					[self.progressBar setMinValue:0];
					[self.progressBar setMaxValue:self.totalUploads - 1];
					
					[self downloadNextUploadInBackground];
				}
				else {
					[self.queuedUploads addObjectsFromArray:new_posts];
					NSInteger new_offset = [offset integerValue] + limit;
					[self downloadUploadsInBackgroundWithOffset:new_offset];
				}
			});
		}
	}];
}

- (void) downloadNextUploadInBackground
{
	[self performSelectorInBackground:@selector(downloadNextUpload) withObject:nil];
}

- (void) downloadNextUpload
{
	RFUpload* up = [self.queuedUploads firstObject];
	if (up) {
		NSURL* url = [NSURL URLWithString:up.url];
		NSString* s = [NSString stringWithFormat:@"Downloading %@...", [url.pathComponents lastObject]];
		
		RFDispatchMainAsync (^{
			[self.statusField setStringValue:s];
			[self.progressBar setDoubleValue:self.totalUploads - self.queuedUploads.count];
		});
		
		[self downloadURL:up.url withCompletion:^{
			[self.queuedUploads removeObject:up];
			[self downloadNextUpload];
		}];
	}
	else {
		RFDispatchMainAsync (^{
			// enable close button
			self.window.styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
			
			// finish progress and set reveal button
			[self.progressBar stopAnimation:nil];
			[self.statusField setStringValue:@"Finished export."];
			[self.cancelButton setTitle:@"Reveal Folder"];
			[self.cancelButton setAction:@selector(revealFolder:)];
		});
	}
}

- (void) downloadURL:(NSString *)url withCompletion:(void (^)(void))handler
{
	NSError* error = nil;

	NSString* uploads_folder = [self.exportFolder stringByAppendingPathComponent:@"uploads"];
	[[NSFileManager defaultManager] createDirectoryAtPath:uploads_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSURL* download_url = [NSURL URLWithString:url];
	NSString* filename = [download_url.pathComponents lastObject];
	NSString* download_path = [uploads_folder stringByAppendingPathComponent:filename];
	
	// this is called from a thread so we'll keep it simple
	NSData* d = [NSData dataWithContentsOfURL:download_url];
	[d writeToFile:download_path atomically:NO];

	// wait a second so we don't hit the server too much
	[NSThread sleepForTimeInterval:1];

	handler();
}

- (NSString *) prepareExportFolder
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
	
	return export_folder;
}

- (NSString *) writePost:(RFPost *)post
{
	return [self writePost:post includeFrontmatter:YES];
}

- (NSString *) writePost:(RFPost *)post includeFrontmatter:(BOOL)includeFrontmatter
{
	self.exportFolder = [self prepareExportFolder];

	NSError* error = nil;

	NSDateComponents* components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:post.postedAt];

	NSString* date_name = [NSString stringWithFormat:@"%ld", (long)components.year];
	NSString* date_folder = [self.exportFolder stringByAppendingPathComponent:date_name];
	[[NSFileManager defaultManager] createDirectoryAtPath:date_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* month_name = [NSString stringWithFormat:@"%02ld", (long)components.month];
	NSString* month_folder = [date_folder stringByAppendingPathComponent:month_name];
	[[NSFileManager defaultManager] createDirectoryAtPath:month_folder withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* file_content = post.text;
	
	if (includeFrontmatter) {
		NSMutableString* with_frontmatter = [NSMutableString string];
		[with_frontmatter appendString:@"---\n"];
		[with_frontmatter appendFormat:@"title: \"%@\"\n", [post.title rf_stringEscapingQuotes]];
		[with_frontmatter appendFormat:@"date: %@\n", post.postedAt];

		NSURL* url = [NSURL URLWithString:post.url];
		[with_frontmatter appendFormat:@"url: %@\n", url.path];
		
		if (post.categories.count > 0) {
			[with_frontmatter appendString:@"categories:\n"];
			for (NSString* c in post.categories) {
				[with_frontmatter appendFormat:@"- \"%@\"\n", [c rf_stringEscapingQuotes]];
			}
		}
		
		[with_frontmatter appendString:@"---\n"];
		[with_frontmatter appendString:file_content];
		file_content = with_frontmatter;
	}
	
	NSString* filename = [NSString stringWithFormat:@"%@.md", post.postID];
	NSString* markdown_path = [month_folder stringByAppendingPathComponent:filename];
	[file_content writeToFile:markdown_path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	
	return markdown_path;
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
