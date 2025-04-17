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
#import "MMMarkdown.h"
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

- (NSString *) placeholderForPost:(RFPost *)post
{
	return [NSString stringWithFormat:@"[placeholder_post_%@]", post.postID];
}

- (NSXMLDocument *) makeHTML
{
	NSXMLElement* root = [NSXMLNode elementWithName:@"html"];
	NSXMLDocument* doc = [[NSXMLDocument alloc] initWithRootElement:root];
	[doc setDocumentContentKind:NSXMLDocumentHTMLKind];
	[doc setCharacterEncoding:@"UTF-8"];
	
	NSXMLElement* body = [NSXMLNode elementWithName:@"body"];
	[root addChild:body];

	NSXMLElement* feed_div = [NSXMLNode elementWithName:@"div"];
	[body addChild:feed_div];

	NSXMLNode* feed_class = [NSXMLNode attributeWithName:@"class" stringValue:@"h-feed"];
	[feed_div addAttribute:feed_class];

	for (RFPost* post in self.posts) {
		NSXMLElement* entry_div = [NSXMLNode elementWithName:@"div"];
		[feed_div addChild:entry_div];

		NSXMLNode* entry_class = [NSXMLNode attributeWithName:@"class" stringValue:@"h-entry"];
		[entry_div addAttribute:entry_class];

		if (post.title.length > 0) {
			NSXMLElement* h1_tag = [NSXMLNode elementWithName:@"h1" stringValue:post.title];
			[entry_div addChild:h1_tag];

			NSXMLNode* h1_class = [NSXMLNode attributeWithName:@"class" stringValue:@"p-name"];
			[h1_tag addAttribute:h1_class];
		}

		NSXMLElement* a_tag = [NSXMLNode elementWithName:@"a"];
		[entry_div addChild:a_tag];

		NSXMLNode* a_href = [NSXMLNode attributeWithName:@"href" stringValue:post.url];
		[a_tag addAttribute:a_href];

		NSXMLNode* a_class = [NSXMLNode attributeWithName:@"class" stringValue:@"u-url"];
		[a_tag addAttribute:a_class];

		NSXMLElement* time_tag = [NSXMLNode elementWithName:@"time" stringValue:[post.postedAt description]];
		[a_tag addChild:time_tag];

		NSXMLNode* time_datetime = [NSXMLNode attributeWithName:@"datetime" stringValue:[post.postedAt uuRfc3339String]];
		[time_tag addAttribute:time_datetime];

		NSXMLNode* time_class = [NSXMLNode attributeWithName:@"class" stringValue:@"dt-published"];
		[time_tag addAttribute:time_class];

		NSXMLElement* content_div = [NSXMLNode elementWithName:@"div"];
		[entry_div addChild:content_div];

		NSXMLNode* content_class = [NSXMLNode attributeWithName:@"class" stringValue:@"e-content"];
		[content_div addAttribute:content_class];
		
		NSString* placeholder = [self placeholderForPost:post];
		
		NSXMLNode* content_html = [NSXMLNode textWithStringValue:placeholder];
		[content_div addChild:content_html];
	}
	
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
		
		NSError* error = nil;
		NSString* post_html = [MMMarkdown HTMLStringWithMarkdown:post.text extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
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

- (void) finishExport
{
	NSError* error = nil;

	NSXMLDocument* doc = [self makeHTML];
	NSString* html_s = [doc XMLString];
	
	for (RFPost* post in self.posts) {
		NSError* error = nil;
		NSString* post_html = [MMMarkdown HTMLStringWithMarkdown:post.text extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
		NSString* post_placeholder = [self placeholderForPost:post];
		html_s = [html_s stringByReplacingOccurrencesOfString:post_placeholder withString:post_html];
	}

	NSString* html_path = [self.exportFolder stringByAppendingPathComponent:@"index.html"];
	[html_s writeToFile:html_path atomically:YES encoding:NSUTF8StringEncoding error:&error];

	NSDictionary* info = [self makeJSON];
	NSData* d = [NSJSONSerialization dataWithJSONObject:info options:0 error:&error];
	NSString* json_s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

	NSString* json_path = [self.exportFolder stringByAppendingPathComponent:@"feed.json"];
	[json_s writeToFile:json_path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	
	NSString* downloads_folder = [self.exportFolder stringByDeletingLastPathComponent];
	NSString* zip_path = [downloads_folder stringByAppendingPathComponent:@"Micro.blog.bar"];
	[SSZipArchive createZipFileAtPath:zip_path withContentsOfDirectory:self.exportFolder];
	
	NSString* new_path = [self promptSave:@"Micro.blog.bar"];
	if (new_path) {
		[self copyItemAtPath:zip_path toPath:new_path];
	}

	[self cleanupExport];
}

@end
