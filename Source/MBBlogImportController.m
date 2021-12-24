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
#import "RFMicropub.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "UUDate.h"
#import "RFMacros.h"
#import "NSAlert+Extras.h"
#import "SAMKeychain.h"
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

			[self setupSummary];
		}
		else {
			self.summaryField.stringValue = @"Could not process JSON Feed.";
		}
		
		[self gatherUploads:self.unzippedPath];
	}
	else {
		self.summaryField.stringValue = @"Could not uncompress the archive file.";
	}
}

- (void) setupSummary
{
	if (self.posts.count == 1) {
		self.summaryField.stringValue = @"1 post";
	}
	else {
		self.summaryField.stringValue = [NSString stringWithFormat:@"%lu posts", (unsigned long)self.posts.count];
	}
}

- (void) gatherUploads:(NSString *)path
{
	NSMutableArray* new_paths = [NSMutableArray array];

	NSURL* folder_url = [NSURL fileURLWithPath:path];
	NSArray* keys = @[ NSURLIsDirectoryKey, NSURLIsPackageKey, NSURLLocalizedNameKey ];

	NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtURL:folder_url includingPropertiesForKeys:keys options:(NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:^(NSURL *url, NSError *error) {
		// continue after errors
		return YES;
	}];

	for (NSURL* url in enumerator) {
		NSNumber* is_dir = nil;
		[url getResourceValue:&is_dir forKey:NSURLIsDirectoryKey error:NULL];
		if (![is_dir boolValue]) {
			NSString* filename = [url lastPathComponent];
			if (![filename isEqualToString:@"feed.json"] && ![filename isEqualToString:@"index.html"]) {
				// we want a list of all the files except the special feed.json and index.html
				[new_paths addObject:[url path]];
			}
		}
	}
	
	self.files = new_paths;
}

- (IBAction) runImport:(id)sender
{
	if (self.isRunning) {
		self.importButton.enabled = NO;
		self.isStopping = YES;
	}
	else {
		self.isRunning = YES;
		self.isStopping = NO;
		
		self.progressBar.hidden = NO;
		self.summaryField.hidden = YES;
		[self.progressBar startAnimation:nil];
		[self.importButton setTitle:@"Stop"];
		
		self.queuedPosts = [self.posts mutableCopy];
		self.queuedFiles = [self.files mutableCopy];
		[self.progressBar setMaxValue:self.posts.count + self.files.count];
		[self.progressBar setDoubleValue:1];

		[self uploadNextFileInBackground];
	}
}

#pragma mark -

- (void) uploadNextPostInBackground
{
	[self performSelectorInBackground:@selector(uploadNextPost) withObject:nil];
}

- (void) uploadNextPost
{
	if (self.isStopping) {
		[self performSelectorOnMainThread:@selector(finishedImport) withObject:nil waitUntilDone:NO];
		return;
	}

	if (self.queuedPosts.count > 0) {
		RFPost* post = [self.queuedPosts firstObject];
		[self.queuedPosts removeObject:post];

		NSArray* files = [self uploadedFilesInPost:post];
		if (files.count > 0) {
			// update HTML?
			// ...
			
			[self uploadPost:post completion:^{
				[self uploadNextPostInBackground];
			}];
		}
		else {
			[self uploadPost:post completion:^{
				[self uploadNextPostInBackground];
			}];
		}
		
		[self performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
	}
	else {
		[self performSelectorOnMainThread:@selector(finishedImport) withObject:nil waitUntilDone:NO];
	}
}

- (void) uploadPost:(RFPost *)post completion:(void (^)(void))handler
{
	if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
		RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
		NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
		if (destination_uid == nil) {
			destination_uid = @"";
		}
		NSDictionary* args = @{
			@"name": @"",
			@"content": post.text,
			@"published": [post.postedAt uuRfc3339StringForUTCTimeZone],
			@"mp-destination": destination_uid
		};

		[client postWithParams:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
					NSString* msg = response.parsedResponse[@"error_description"];
					[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
				}
				else {
					handler();
				}
			});
		}];
	}
	else if ([self hasMicropubBlog]) {
		NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubPostingEndpoint];
		RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
		NSDictionary* args = @{
			@"h": @"entry",
			@"name": @"",
			@"content": post.text,
			@"published": [post.postedAt uuRfc3339StringForUTCTimeZone]
		};
		
		[client postWithParams:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
					NSString* msg = response.parsedResponse[@"error_description"];
					[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
				}
				else {
					handler();
				}
			});
		}];
	}
	else {
		NSString* xmlrpc_endpoint = [RFSettings stringForKey:kExternalBlogEndpoint];
		NSString* blog_s = [RFSettings stringForKey:kExternalBlogID];
		NSString* username = [RFSettings stringForKey:kExternalBlogUsername];
		NSString* password = [SAMKeychain passwordForService:@"ExternalBlog" account:username];
		
		NSString* post_text = post.text;
		NSString* app_key = @"";
		NSNumber* blog_id = [NSNumber numberWithInteger:[blog_s integerValue]];
		RFBoolean* publish = [[RFBoolean alloc] initWithBool:YES];

		NSString* post_format = [RFSettings stringForKey:kExternalBlogFormat];
		NSString* post_category = [RFSettings stringForKey:kExternalBlogCategory];

		NSArray* params;
		NSString* method_name;

		if ([[RFSettings stringForKey:kExternalBlogApp] isEqualToString:@"WordPress"]) {
			NSMutableDictionary* content = [NSMutableDictionary dictionary];
			
			content[@"post_status"] = @"publish";
			content[@"post_title"] = @"";
			content[@"post_content"] = post_text;
			content[@"post_date"] = post.postedAt;
			if (post_format.length > 0) {
				content[@"post_format"] = post_format;
			}
			if (post_category.length > 0) {
				content[@"terms"] = @{
					@"category": @[ post_category ]
				};
			}

			params = @[ blog_id, username, password, content ];
			method_name = @"wp.newPost";
		}
		else {
			params = @[ app_key, blog_id, username, password, post_text, publish ];
			method_name = @"blogger.newPost";
		}
		
		RFXMLRPCRequest* request = [[RFXMLRPCRequest alloc] initWithURL:xmlrpc_endpoint];
		[request sendMethod:method_name params:params completion:^(UUHttpResponse* response) {
			RFXMLRPCParser* xmlrpc = [RFXMLRPCParser parsedResponseFromData:response.rawResponse];
			RFDispatchMainAsync ((^{
				if (xmlrpc.responseFault) {
					NSString* s = [NSString stringWithFormat:@"%@ (error: %@)", xmlrpc.responseFault[@"faultString"], xmlrpc.responseFault[@"faultCode"]];
					[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:s button:@"OK" completionHandler:NULL];
				}
				else {
					handler();
				}
			}));
		}];
	}
}

- (void) uploadNextFileInBackground
{
	[self performSelectorInBackground:@selector(uploadNextFile) withObject:nil];
}

- (void) uploadNextFile
{
	if (self.isStopping) {
		[self performSelectorOnMainThread:@selector(finishedImport) withObject:nil waitUntilDone:NO];
		return;
	}
	
	if (self.queuedFiles.count > 0) {
		NSString* path = [self.queuedFiles firstObject];
		[self.queuedFiles removeObject:path];

		[self uploadFile:path completion:^{
			[self uploadNextFileInBackground];
		}];
		
		[self performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
	}
	else {
		// move on to uploading posts
		[self uploadNextPostInBackground];
	}
}

- (void) uploadFile:(NSString *)path completion:(void (^)(void))handler
{
	handler();
}

- (void) updateProgress
{
	NSUInteger remaining = (self.posts.count - self.queuedPosts.count) + (self.files.count - self.queuedFiles.count);
	[self.progressBar setDoubleValue:remaining];
}

- (void) finishedImport
{
	self.importButton.enabled = YES;
	[self.importButton setTitle:@"Import"];
	self.progressBar.hidden = YES;

	if (self.isStopping) {
		[self setupSummary];
	}
	else {
		self.summaryField.stringValue = @"Import finished.";
	}
	
	self.summaryField.hidden = NO;
	[self.progressBar stopAnimation:nil];
	
	self.isStopping = NO;
	self.isRunning = NO;
}

- (NSArray *) uploadedFilesInPost:(RFPost *)post
{
	NSMutableArray* paths = [NSMutableArray array];
	
	for (NSString* file in self.files) {
		NSString* filename = [file lastPathComponent];
		NSString* parent = [[file stringByDeletingLastPathComponent] lastPathComponent];
		NSString* relative_path = [NSString stringWithFormat:@"%@/%@", parent, filename];
		
		// check if the post contains a reference to this file, e.g. "2021/file.jpg"
		if ([post.text containsString:relative_path]) {
			[paths addObject:file];
		}
	}
	
	return paths;
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

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return NO;
}

@end
