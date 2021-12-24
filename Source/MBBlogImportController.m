//
//  MBBlogImportController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/23/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "MBBlogImportController.h"

#import "RFClient.h"
#import "RFSettings.h"
#import "RFPost.h"
#import "RFPostCell.h"
#import "UUDate.h"
#import <ZipArchive.h>

@implementation MBBlogImportController

- (instancetype) initWithFile:(NSString *)path
{
	self = [super initWithWindowNibName:@"BlogImport"];
	if (self) {
		self.path = path;
	}
	
	return self;
}

- (void) dealloc
{
	if ([self.unzippedPath containsString:@"Micro.blog"]) { // sanity check
		[[NSFileManager defaultManager] removeItemAtPath:self.unzippedPath error:NULL];
	}
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self.window setTitle:[self.path lastPathComponent]];
	
	[self setupTable];
	[self setupHostname];
	[self setupPosts];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
}

- (void) setupHostname
{
	if ([self hasAnyBlog]) {
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
			if (s) {
				self.hostnameField.stringValue = s;
			}
			else {
				self.hostnameField.stringValue = [RFSettings stringForKey:kAccountDefaultSite];
			}
		}
		else if ([self hasMicropubBlog]) {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalMicropubMe];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.hostnameField.stringValue = endpoint_url.host;
		}
		else {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalBlogEndpoint];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.hostnameField.stringValue = endpoint_url.host;
		}
	}
	else {
		self.hostnameField.stringValue = @"No blog configured.";
		self.importButton.enabled = NO;
	}
}

- (void) setupPosts
{
	NSString* temp_filename = [NSString stringWithFormat:@"Micro.blog-%@", [[NSUUID UUID] UUIDString]];
	NSString* dest_path = [NSTemporaryDirectory() stringByAppendingPathComponent:temp_filename];
	if ([SSZipArchive unzipFileAtPath:self.path toDestination:dest_path]) {
		self.unzippedPath = dest_path;
		NSString* feed_path = [dest_path stringByAppendingPathComponent:@"feed.json"];
		
		NSData* d = [NSData dataWithContentsOfFile:feed_path];
		NSError* error = nil;
		id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:&error];
		if ([obj isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];
			
			NSArray* items = [obj objectForKey:@"items"];
			for (NSDictionary* info in items) {
				RFPost* new_post = [[RFPost alloc] init];
				
				// first try content_text, which we assume is original Markdown
				new_post.text = [info objectForKey:@"content_text"];
				if (new_post.text == nil) {
					new_post.text = [info objectForKey:@"content_html"];
				}
				
				NSString* date_s = [info objectForKey:@"date_published"];
				new_post.postedAt = [NSDate uuDateFromRfc3339String:date_s];
				new_post.title = [info objectForKey:@"title"];
				
				[new_posts addObject:new_post];
			}
			
			self.posts = new_posts;
			[self.tableView reloadData];
			
			if (self.posts.count == 1) {
				self.summaryField.stringValue = @"1 post";
			}
			else {
				self.summaryField.stringValue = [NSString stringWithFormat:@"%lu posts", (unsigned long)self.posts.count];
			}
		}
	}
	else {
		self.summaryField.stringValue = @"Could not uncompress the archive file.";
	}
}

- (IBAction) runImport:(id)sender
{
}

#pragma mark -

- (BOOL) hasAnyBlog
{
	BOOL has_hosted = [RFSettings boolForKey:kHasSnippetsBlog];
	NSString* micropub = [RFSettings stringForKey:kExternalMicropubMe];
	NSString* xmlrpc = [RFSettings stringForKey:kExternalBlogEndpoint];
	return (has_hosted || micropub || xmlrpc);
}

- (BOOL) hasSnippetsBlog
{
	return [RFSettings boolForKey:kHasSnippetsBlog];
}

- (BOOL) hasMicropubBlog
{
	return ([RFSettings stringForKey:kExternalMicropubMe] != nil);
}

- (BOOL) prefersExternalBlog
{
	return [RFSettings boolForKey:kExternalBlogIsPreferred];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.posts.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

	if (row < self.posts.count) {
		RFPost* post = [self.posts objectAtIndex:row];
		[cell setupWithPost:post];
	}

	return cell;
}

//- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
//{
//	NSString* value = @"";
//
//	RFPost* post = [self.posts objectAtIndex:row];
//
//	if ([tableColumn.identifier isEqualToString:@"text"]) {
//		value = post.text;
//	}
//	else if ([tableColumn.identifier isEqualToString:@"date"]) {
//		value = [post.postedAt uuIso8601DateString];
//	}
//
//	return value;
//}
//
//- (NSCell *) tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
//{
//	NSTextFieldCell* cell = [tableColumn dataCellForRow:row];
//	return cell;
//}

@end
