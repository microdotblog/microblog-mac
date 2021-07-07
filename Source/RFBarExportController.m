//
//  RFBarExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/7/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFBarExportController.h"

#import "RFPost.h"
#import "UUDate.h"
#import <ZipArchive.h>

@implementation RFBarExportController

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	self.posts = [NSMutableArray array];
}

- (NSString *) writePost:(RFPost *)post
{
	[self.posts addObject:post];
	
	return post.text;
}

- (NSXMLDocument *) makeHTML
{
	NSXMLElement* root = [NSXMLNode elementWithName:@"html"];
	NSXMLDocument* doc = [[NSXMLDocument alloc] initWithRootElement:root];
	[doc setVersion:@"1.0"];
	[doc setCharacterEncoding:@"UTF-8"];
	
	// ...
	
	return doc;
}

- (NSDictionary *) makeJSON
{
	NSMutableArray* items = [NSMutableArray array];
	
	for (RFPost* post in self.posts) {
		NSMutableDictionary* info = [NSMutableDictionary dictionary];
		
		[info setValue:post.postID forKey:@"id"];
		[info setValue:post.title forKey:@"title"];
		[info setValue:post.text forKey:@"content_text"];
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

- (void) finishExport
{
	NSError* error = nil;

	NSXMLDocument* doc = [self makeHTML];
	NSString* html_s = [doc XMLString];

	NSString* html_path = [self.exportFolder stringByAppendingPathComponent:@"index.html"];
	[html_s writeToFile:html_path atomically:YES encoding:NSUTF8StringEncoding error:&error];

	NSDictionary* info = [self makeJSON];
	NSData* d = [NSJSONSerialization dataWithJSONObject:info options:0 error:&error];
	NSString* json_s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

	NSString* json_path = [self.exportFolder stringByAppendingPathComponent:@"feed.json"];
	[json_s writeToFile:json_path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	
	NSString* downloads_folder = [self.exportFolder stringByDeletingLastPathComponent];
	NSString* zip_path = [downloads_folder stringByAppendingPathComponent:@"Blog.bar"];
	[SSZipArchive createZipFileAtPath:zip_path withContentsOfDirectory:self.exportFolder];
	
	// TODO: switch to using temp folder and prompt for final location
	// ...
}

@end
