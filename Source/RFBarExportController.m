//
//  RFBarExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/7/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFBarExportController.h"

#import "RFPost.h"
#import "RFSettings.h"
#import "UUDate.h"
#import "MMMarkdown.h"
#import <ZipArchive.h>

@implementation RFBarExportController

- (instancetype) init
{
	self = [super init];
	if (self) {
		self.posts = [NSMutableArray array];
	}

	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
}

- (void) exportToPath:(NSString *)path progress:(void (^)(double progress))progressHandler status:(void (^)(NSString* status))statusHandler completion:(void (^)(BOOL success, NSString* _Nullable path))completionHandler
{
	self.destinationPath = path;
	self.progressHandler = progressHandler;
	self.statusHandler = statusHandler;
	self.completionHandler = completionHandler;

	[self startExport];
}

- (NSString *) writePost:(RFPost *)post
{
	[self.posts addObject:post];
	
	return post.text;
}

- (NSString *) escapedHTMLString:(NSString *)s
{
	if (s == nil) {
		return @"";
	}

	NSMutableString* result = [s mutableCopy];
	[result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (NSString *) escapedHTMLAttributeString:(NSString *)s
{
	NSMutableString* result = [[self escapedHTMLString:s] mutableCopy];
	[result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
	return result;
}

- (NSArray *) renderedPostsForPosts:(NSArray *)posts
{
	NSMutableArray* rendered_posts = [NSMutableArray array];
	for (RFPost* post in posts) {
		NSError* error = nil;
		NSString* post_text = post.text ?: @"";
		NSString* post_html = [MMMarkdown HTMLStringWithMarkdown:post_text extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
		if (post_html == nil) {
			post_html = @"";
		}

		[rendered_posts addObject:@{
			@"post": post,
			@"html": post_html
		}];
	}

	return rendered_posts;
}

- (NSString *) makeHTMLWithRenderedPosts:(NSArray *)renderedPosts
{
	NSMutableString* html = [NSMutableString string];
	[html appendString:@"<html><body><div class=\"h-feed\">"];

	for (NSDictionary* rendered_post in renderedPosts) {
		RFPost* post = [rendered_post objectForKey:@"post"];
		NSString* post_html = [rendered_post objectForKey:@"html"];
		NSString* posted_at = [post.postedAt description];
		NSString* posted_at_rfc3339 = [post.postedAt uuRfc3339String];

		[html appendString:@"<div class=\"h-entry\">"];
		if (post.title.length > 0) {
			[html appendFormat:@"<h1 class=\"p-name\">%@</h1>", [self escapedHTMLString:post.title]];
		}

		[html appendFormat:@"<a href=\"%@\" class=\"u-url\"><time datetime=\"%@\" class=\"dt-published\">%@</time></a>",
			[self escapedHTMLAttributeString:post.url],
			[self escapedHTMLAttributeString:posted_at_rfc3339],
			[self escapedHTMLString:posted_at]
		];
		[html appendFormat:@"<div class=\"e-content\">%@</div>", post_html];
		[html appendString:@"</div>"];
	}
	
	[html appendString:@"</div></body></html>"];
	return html;
}

- (NSDictionary *) makeJSONWithRenderedPosts:(NSArray *)renderedPosts
{
	NSMutableArray* items = [NSMutableArray array];
	
	for (NSDictionary* rendered_post in renderedPosts) {
		RFPost* post = [rendered_post objectForKey:@"post"];
		NSString* post_html = [rendered_post objectForKey:@"html"];
		NSMutableDictionary* info = [NSMutableDictionary dictionary];
		
		[info setValue:post.postID forKey:@"id"];
		[info setValue:post.title forKey:@"title"];
		[info setValue:post.text forKey:@"content_text"];
		[info setValue:post_html forKey:@"content_html"];

		[info setValue:post.url forKey:@"url"];
		[info setValue:[post.postedAt uuRfc3339String] forKey:@"date_published"];

		[items addObject:info];
	}
	
	NSDictionary* root = @{
		@"version": @"https://jsonfeed.org/version/1.1",
		@"title": @"Blog Archive",
		@"items": items
	};

	return root;
}

- (NSString *) createArchiveInExportFolder:(NSString *)exportFolder posts:(NSArray *)posts error:(NSError **)error
{
	NSArray* rendered_posts = [self renderedPostsForPosts:posts];

	NSString* html_s = [self makeHTMLWithRenderedPosts:rendered_posts];

	NSString* html_path = [exportFolder stringByAppendingPathComponent:@"index.html"];
	if (![html_s writeToFile:html_path atomically:YES encoding:NSUTF8StringEncoding error:error]) {
		return nil;
	}

	NSDictionary* info = [self makeJSONWithRenderedPosts:rendered_posts];
	NSData* d = [NSJSONSerialization dataWithJSONObject:info options:0 error:error];
	if (d == nil) {
		return nil;
	}
	NSString* json_s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

	NSString* json_path = [exportFolder stringByAppendingPathComponent:@"feed.json"];
	if (![json_s writeToFile:json_path atomically:YES encoding:NSUTF8StringEncoding error:error]) {
		return nil;
	}
	
	NSString* downloads_folder = [exportFolder stringByDeletingLastPathComponent];
	NSString* zip_path = [downloads_folder stringByAppendingPathComponent:@"Micro.blog.bar"];
	if (![SSZipArchive createZipFileAtPath:zip_path withContentsOfDirectory:exportFolder]) {
		return nil;
	}
	
	return zip_path;
}

- (BOOL) copyExportFileAtPath:(NSString *)sourcePath toPath:(NSString *)destPath error:(NSError **)error
{
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL is_folder = NO;
	if ([fm fileExistsAtPath:destPath isDirectory:&is_folder]) {
		if (is_folder) {
			return NO;
		}

		NSURL* source_url = [NSURL fileURLWithPath:sourcePath];
		NSURL* dest_url = [NSURL fileURLWithPath:destPath];
		return [fm replaceItemAtURL:dest_url withItemAtURL:source_url backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:error];
	}
	else {
		return [fm copyItemAtPath:sourcePath toPath:destPath error:error];
	}
}

- (void) cleanupExportFolder:(NSString *)exportFolder
{
	NSString* temp_folder = NSTemporaryDirectory();
	if ((exportFolder.length > 0) && [exportFolder containsString:temp_folder] && [exportFolder containsString:@"Micro.blog"]) {
		NSError* error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:exportFolder error:&error];

		NSString* parent_folder = [exportFolder stringByDeletingLastPathComponent];
		if ((parent_folder.length > 0) && [parent_folder containsString:temp_folder] && [parent_folder containsString:@"Micro.blog"]) {
			[[NSFileManager defaultManager] removeItemAtPath:parent_folder error:&error];
			[RFSettings removeTemporaryFolder:parent_folder];
		}
	}
}

- (void) finishExport
{
	NSArray* posts = [self.posts copy];
	NSString* export_folder = [self.exportFolder copy];
	NSString* destination_path = [self.destinationPath copy];

	if (destination_path) {
		[self updateExportStatus:@"Creating archive..."];
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
			NSError* error = nil;
			NSString* zip_path = [self createArchiveInExportFolder:export_folder posts:posts error:&error];
			BOOL success = NO;
			if (zip_path) {
				success = [self copyExportFileAtPath:zip_path toPath:destination_path error:&error];
			}
			[self cleanupExportFolder:export_folder];

			dispatch_async(dispatch_get_main_queue(), ^{
				if (self.completionHandler && !self.hasFinished) {
					self.hasFinished = YES;
					self.completionHandler(success, destination_path);
				}
			});
		});
	}
	else {
		NSError* error = nil;
		NSString* zip_path = [self createArchiveInExportFolder:export_folder posts:posts error:&error];
		NSString* new_path = [self promptSave:@"Micro.blog.bar"];
		if (zip_path && new_path) {
			[self copyItemAtPath:zip_path toPath:new_path];
		}
		[self cleanupExportFolder:export_folder];
	}
}

- (BOOL) finishExportCompletesAsynchronously
{
	return self.destinationPath != nil;
}

- (void) finishCancel
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.completionHandler && !self.hasFinished) {
			self.hasFinished = YES;
			self.completionHandler(NO, nil);
		}
	});

	[super finishCancel];
}

@end
