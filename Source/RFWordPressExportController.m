//
//  RFWordPressExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/7/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFWordPressExportController.h"

#import "RFPost.h"
#import "RFUpload.h"
#import "UUDate.h"

@implementation RFWordPressExportController

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	self.posts = [NSMutableArray array];
	self.uploads = [NSMutableArray array];
}

- (NSString *) writePost:(RFPost *)post
{
	[self.posts addObject:post];
	
	return post.text;
}

- (void) downloadURL:(NSString *)url forUpload:(RFUpload *)upload withCompletion:(void (^)(void))handler
{
	[self.uploads addObject:upload];

	// we don't really need to download URLs for WordPress
	handler();
}

- (NSXMLDocument *) makeWordPressXML
{
	NSXMLElement* root = [NSXMLNode elementWithName:@"rss"];
	NSXMLDocument* doc = [[NSXMLDocument alloc] initWithRootElement:root];
	[doc setVersion:@"1.0"];
	[doc setCharacterEncoding:@"UTF-8"];
	
	NSXMLNode* ns_wp = [NSXMLNode attributeWithName:@"xmlns:wp" stringValue:@"http://wordpress.org/export/1.2/"];
	[root addAttribute:ns_wp];

	NSXMLNode* ns_dc = [NSXMLNode attributeWithName:@"xmlns:dc" stringValue:@"http://purl.org/dc/elements/1.1/"];
	[root addAttribute:ns_dc];

	NSXMLNode* ns_content = [NSXMLNode attributeWithName:@"xmlns:content" stringValue:@"http://purl.org/rss/1.0/modules/content/"];
	[root addAttribute:ns_content];

	NSXMLNode* rss_version = [NSXMLNode attributeWithName:@"version" stringValue:@"2.0"];
	[root addAttribute:rss_version];

	NSXMLElement* channel = [NSXMLNode elementWithName:@"channel"];
	[root addChild:channel];
	
	NSXMLElement* wxr_version = [NSXMLNode elementWithName:@"wp:wxr_version" stringValue:@"1.2"];
	[channel addChild:wxr_version];
	
	for (RFPost* post in self.posts) {
		NSXMLElement* item = [NSXMLNode elementWithName:@"item"];
		[channel addChild:item];
		
		NSXMLElement* title = [NSXMLNode elementWithName:@"title" stringValue:post.title];
		[item addChild:title];

		NSXMLElement* content = [NSXMLNode elementWithName:@"content:encoded" stringValue:post.text];
		[item addChild:content];

		NSXMLElement* status = [NSXMLNode elementWithName:@"wp:status" stringValue:@"publish"];
		[item addChild:status];

		NSXMLElement* post_type = [NSXMLNode elementWithName:@"wp:post_type" stringValue:@"post"];
		[item addChild:post_type];

		NSXMLElement* post_date = [NSXMLNode elementWithName:@"wp:post_date" stringValue:[post.postedAt uuRfc3339String]];
		[item addChild:post_date];

		NSXMLElement* post_date_gmt = [NSXMLNode elementWithName:@"wp:post_date_gmt" stringValue:[post.postedAt uuRfc3339StringForUTCTimeZone]];
		[item addChild:post_date_gmt];

		NSXMLElement* link = [NSXMLNode elementWithName:@"link" stringValue:post.url];
		[item addChild:link];

		NSXMLElement* guid = [NSXMLNode elementWithName:@"guid" stringValue:post.url];
		[item addChild:guid];

		NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
		formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z"; // RFC 2822
		
		NSXMLElement* pub_date = [NSXMLNode elementWithName:@"pubDate" stringValue:[formatter stringFromDate:post.postedAt]];
		[item addChild:pub_date];

		for (NSString* c in post.categories) {
			NSXMLElement* category = [NSXMLNode elementWithName:@"category" stringValue:c];
			[item addChild:category];

			NSXMLNode* category_domain = [NSXMLNode attributeWithName:@"domain" stringValue:@"category"];
			[category addAttribute:category_domain];

			NSString* s = [c lowercaseString];
			s = [s stringByReplacingOccurrencesOfString:@" " withString:@"-"];
			
			NSXMLNode* category_nicename = [NSXMLNode attributeWithName:@"nicename" stringValue:s];
			[category addAttribute:category_nicename];
		}
	}

	for (RFUpload* up in self.uploads) {
		NSXMLElement* item = [NSXMLNode elementWithName:@"item"];
		[channel addChild:item];
		
		NSString* filename = [up.url lastPathComponent];
		
		NSXMLElement* title = [NSXMLNode elementWithName:@"title" stringValue:filename];
		[item addChild:title];
		
		NSXMLElement* content = [NSXMLNode elementWithName:@"content:encoded" stringValue:@""];
		[item addChild:content];

		NSXMLElement* status = [NSXMLNode elementWithName:@"wp:status" stringValue:@"inherit"];
		[item addChild:status];

		NSXMLElement* post_type = [NSXMLNode elementWithName:@"wp:post_type" stringValue:@"attachment"];
		[item addChild:post_type];

		NSXMLElement* post_date = [NSXMLNode elementWithName:@"wp:post_date" stringValue:[up.createdAt uuRfc3339String]];
		[item addChild:post_date];

		NSXMLElement* post_date_gmt = [NSXMLNode elementWithName:@"wp:post_date_gmt" stringValue:[up.createdAt uuRfc3339StringForUTCTimeZone]];
		[item addChild:post_date_gmt];

		NSXMLElement* attachment_url = [NSXMLNode elementWithName:@"wp:attachment_url" stringValue:up.url];
		[item addChild:attachment_url];

		NSXMLElement* link = [NSXMLNode elementWithName:@"link" stringValue:up.url];
		[item addChild:link];

		NSXMLElement* guid = [NSXMLNode elementWithName:@"guid" stringValue:up.url];
		[item addChild:guid];

		NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
		formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z"; // RFC 2822
		
		NSXMLElement* pub_date = [NSXMLNode elementWithName:@"pubDate" stringValue:[formatter stringFromDate:up.createdAt]];
		[item addChild:pub_date];
	}
	
	return doc;
}

- (void) finishExport
{
	NSXMLDocument* doc = [self makeWordPressXML];
	NSString* s = [doc XMLStringWithOptions:NSXMLNodePrettyPrint];

	NSError* error = nil;

	NSString* filename = @"Micro.blog.xml";
	NSString* wxr_path = [self.exportFolder stringByAppendingPathComponent:filename];
	[s writeToFile:wxr_path atomically:YES encoding:NSUTF8StringEncoding error:&error];

	NSString* new_path = [self promptSave:@"Micro.blog.xml"];
	if (new_path) {
		[self copyItemAtPath:wxr_path toPath:new_path];
	}

	[self cleanupExport];
}

@end
