//
//  MBCategoriesController.m
//  Micro.blog
//
//  Created by Manton Reece on 4/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBCategoriesController.h"

#import "MBEditCategoryCell.h"
#import "RFPost.h"
#import "RFPostCell.h"
#import "MBCategory.h"
#import "MBLlama.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "UUDate.h"
#import "NSString+Extras.h"
#import <sys/sysctl.h>

static NSString* const kModelDownloadURL = @"https://s3.amazonaws.com/micro.blog/models/gemma-3-4b-it-Q5_K_M.gguf";
static NSString* const kModelDownloadSize = @"2.8 GB";

@implementation MBCategoriesController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"CategoriesWindow"];
	if (self) {
		self.categories = @[];
		self.allPosts = @[];
		self.currentPosts = @[];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupInfo];
	[self setupTable];
	
	[self updatePostsSummaryField];
	[self fetchCategories];
}
 
- (void) setupInfo
{
	self.sizeField.stringValue = kModelDownloadSize;
	
	if ([self hasModel]) {
		// hide pane by moving it off the top
		self.downloadTopConstrant.constant = -101;
	}
	else if (![self hasSupportedHardware]) {
		self.downloadButton.enabled = NO;
		self.sizeField.stringValue = @"Requires Apple M1 or later.";
	}
	else if (![self hasSupportedMemory]) {
		self.downloadButton.enabled = NO;
		self.sizeField.stringValue = @"Requires at least 16 GB of RAM.";
	}
	else if (![self hasAvailableSpace]) {
		self.downloadButton.enabled = NO;
		self.sizeField.stringValue = @"Requires 3 GB of available disk space.";
	}
}

- (void) setupTable
{
	[self.categoriesTable registerNib:[[NSNib alloc] initWithNibNamed:@"EditCategoryCell" bundle:nil] forIdentifier:@"EditCategoryCell"];
	[self.postsTable registerNib:[[NSNib alloc] initWithNibNamed:@"PostCell" bundle:nil] forIdentifier:@"PostCell"];
}

- (IBAction) downloadModel:(id)sender
{
	if (self.downloadTask) {
		// if already downloading, cancel it
		[self cancelDownload];
		[self.sizeUpdateTimer invalidate];
		self.sizeUpdateTimer = nil;
	}
	else {
		[self startDownload];
	}
}

- (IBAction) autoCategorize:(id)sender
{
	self.numPostsField.hidden = YES;
	[self.workProgressBar startAnimation:nil];
	
	[self fetchAllPosts];
}

- (IBAction) updatePosts:(id)sender
{
	self.numPostsField.hidden = YES;
	[self.workProgressBar startAnimation:nil];
}

#pragma mark -

- (BOOL) hasModel
{
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	NSURL* folder_url = [self modelsFolderURL];
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];

	NSFileManager* fm = [NSFileManager defaultManager];
	return [fm fileExistsAtPath:dest_url.path];
}

- (BOOL) hasAvailableSpace
{
	NSURL* folder_url = [self modelsFolderURL];
	NSError* error = nil;
	NSDictionary* info = [folder_url resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
	if (error) {
		NSLog(@"Error retrieving resource values: %@", error);
		return NO;
	}

	NSNumber* free_bytes = info[NSURLVolumeAvailableCapacityForImportantUsageKey];
	NSDictionary* attrs_dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:folder_url.path error:&error];
	if (error) {
		NSLog(@"Error retrieving file system attributes: %@", error);
		return NO;
	}

	NSNumber* bytes_required = attrs_dict[NSFileSystemFreeSize];
	return free_bytes.unsignedLongLongValue > bytes_required.unsignedLongLongValue;
}

- (BOOL) hasSupportedMemory
{
	uint64_t memsize = 0;
	size_t size = sizeof(memsize);
	if (sysctlbyname("hw.memsize", &memsize, &size, NULL, 0) == 0) {
		// 16 GB
		const uint64_t required = 16ull * 1024 * 1024 * 1024;
		return memsize >= required;
	}
	
	return NO;
}

- (BOOL) hasSupportedHardware
{
	int is_arm64 = 0;
	size_t size = sizeof(is_arm64);
	if (sysctlbyname("hw.optional.arm64", &is_arm64, &size, NULL, 0) == 0) {
		return (is_arm64 != 0);
	}
	
	return NO;
}

- (NSURL *) modelsFolderURL
{
	// build destination path in Application Support/Micro.blog/Models
	NSURL* folder_url = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];

	folder_url = [folder_url URLByAppendingPathComponent:@"Micro.blog" isDirectory:YES];
	folder_url = [folder_url URLByAppendingPathComponent:@"Models" isDirectory:YES];

	[[NSFileManager defaultManager] createDirectoryAtURL:folder_url withIntermediateDirectories:YES attributes:nil error:nil];
	
	return folder_url;
}

- (void) fetchCategories
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub?q=category"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_categories = [NSMutableArray array];
			for (NSString* name in [response.parsedResponse objectForKey:@"categories"]) {
				MBCategory* c = [[MBCategory alloc] init];
				c.name = name;
				[new_categories addObject:c];
			}
			RFDispatchMainAsync ((^{
				self.categories = new_categories;
				[self.categoriesTable reloadData];
			}));
		}
	}];
}

- (void) fetchPostsForCategory
{
	self.numPostsField.hidden = YES;
	[self.workProgressBar startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub?q=source"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];
			for (NSDictionary* item in [response.parsedResponse objectForKey:@"items"]) {
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
				
				post.categories = @[];
				if ([[props objectForKey:@"category"] count] > 0) {
					post.categories = [props objectForKey:@"category"];
				}

				[new_posts addObject:post];
			}
			RFDispatchMainAsync ((^{
				self.currentPosts = new_posts;
				[self.postsTable reloadData];
				[self.workProgressBar stopAnimation:nil];
				[self updatePostsSummaryField];
			}));
		}
	}];
}

- (void) fetchAllPosts
{
	NSInteger offset = self.allPosts.count; // how many posts we already have
	NSDictionary *args = @{
		@"q": @"source",
		@"offset" : @(offset),
		@"limit" : @(100)
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if (![response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			return;
		}
		
		NSArray* items = response.parsedResponse[@"items"];
		
		NSMutableArray* collected = [NSMutableArray arrayWithArray:self.allPosts];
		
		for (NSDictionary* item in items) {
			RFPost* post = [[RFPost alloc] init];
			NSDictionary* props = item[@"properties"];
			
			post.postID = [props[@"uid"] firstObject];
			post.title = [props[@"name"] firstObject];
			post.text = [props[@"content"] firstObject];
			post.url = [props[@"url"] firstObject];
			
			NSString *date_s = [props[@"published"] firstObject];
			post.postedAt = [NSDate uuDateFromRfc3339String:date_s];
			
			NSString *status = [props[@"post-status"] firstObject];
			post.isDraft = [status isEqualToString:@"draft"];
			
			post.categories = @[];
			if ([props[@"category"] count] > 0) {
				post.categories = props[@"category"];
			}
			
			[collected addObject:post];
		}
		
		self.allPosts = [collected copy]; // assign when we've added this batch
		
		// if we got a full batch, keep paging, otherwise we're done
		if (NO && items.count == 100) {
			NSLog(@"Got posts: %lu", (unsigned long)items.count);
			[self fetchAllPosts];
		}
		else {
			// finished
			RFDispatchMainAsync((^{
				[self.postsTable reloadData];
				[self updatePostsSummaryField];
				
				[self performSelectorInBackground:@selector(analyzePosts:) withObject:self.allPosts];
			}));
		}
	}];
}

- (void) analyzePosts:(NSArray *)posts
{
	RFDispatchMain(^{
		self.numPostsField.hidden = YES;
		[self.workProgressBar setIndeterminate:NO];
		self.workProgressBar.doubleValue = 0.0;
		self.workProgressBar.maxValue = posts.count;
	});
	NSInteger i = 0;
	
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	NSURL* folder_url = [self modelsFolderURL];
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];
	MBLlama* llama = [[MBLlama alloc] initWithPath:dest_url.path];
	
	for (RFPost* post in posts) {
		NSMutableString* prompt = [[NSMutableString alloc] init];
		[prompt appendString:@"You are a keyword extractor. You must only output comma-separated list of keywords about the following text. Output on a single line, no quotes, nothing else except the keywords and commas.\n\n"];
		[prompt appendString:post.text];
		
		NSString* answer = [llama runPrompt:prompt];
		NSArray* keywords = [self lastLineKeywordsWithCommasFromText:answer];
		NSLog(@"Answer: %@", keywords);
		
		i++;
		RFDispatchMain(^{
			self.workProgressBar.doubleValue = i;
		});

	}
}

- (NSArray *) lastLineKeywordsWithCommasFromText:(NSString *)text
{
	// break the string into lines
	NSCharacterSet *newlineSet = [NSCharacterSet newlineCharacterSet];
	NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:newlineSet];
	
	// walk backwards so we can stop at the first match.
	for (NSInteger i = lines.count - 1; i >= 0; i--) {
		NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([line rangeOfString:@","].location != NSNotFound) {
			// found the last comma‑containing line
			NSMutableArray* cleaned_values = [[NSMutableArray alloc] init];
			for (NSString* value in [line componentsSeparatedByString:@","]) {
				// trip whitespace
				NSString* s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

				// trim leading "#" if present like a hashatg
				if ([s hasPrefix:@"#"]) {
					s = [s substringFromIndex:1];
				}
				
				// sometimes model outputs keywords prefix for our answer
				s = [s lowercaseString];
				s = [s stringByReplacingOccurrencesOfString:@"keywords: " withString:@""];

				// sometimes model has phrases, skip those if more than 3 words
				NSUInteger num_spaces = [[s componentsSeparatedByString:@" "] count] - 1;
				if (num_spaces <= 2) {
					[cleaned_values addObject:s];
				}
			}
			return cleaned_values;
		}
	}

	return @[];
}
- (void) startDownload
{
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	NSURL* folder_url = [self modelsFolderURL];
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];
	self.modelDestinationPath = dest_url.path;
	
	// configure and show progress bar
	self.modelProgressBar.minValue = 0.0;
	self.modelProgressBar.maxValue = 100.0;
	self.modelProgressBar.doubleValue = 0.0;
	[self.modelProgressBar setHidden:NO];
	[self.modelProgressBar startAnimation:nil];
	
	// start a 1‑second timer for updating the size field
	self.sizeUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateSizeField:) userInfo:nil repeats:YES];
	
	// start the download
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	self.downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];

	self.downloadStartDate = [NSDate date];
	self.expectedBytes = 0;
	self.remainingSeconds = 0;
	self.latestDownloadedString = @"0 bytes";
	
	self.downloadTask = [self.downloadSession downloadTaskWithURL:url];
	[self.downloadTask resume];
	
	[self.downloadButton setTitle:@"Cancel"];
}

- (void) cancelDownload
{
	[self.downloadTask cancel];
	self.downloadTask = nil;
	[self.downloadSession invalidateAndCancel];
	self.downloadSession = nil;
	
	[self.sizeUpdateTimer invalidate];
	self.sizeUpdateTimer = nil;
	self.latestDownloadedString = nil;
	
	[self.modelProgressBar stopAnimation:nil];
	self.modelProgressBar.doubleValue = 0.0;
	[self.modelProgressBar setHidden:YES];
	
	self.sizeField.stringValue = kModelDownloadSize;
	[self.downloadButton setTitle:@"Download"];
	
	self.downloadStartDate = nil;
	self.expectedBytes = 0;
	self.remainingSeconds = 0;
}

- (void) finishedDownload
{
	[self setupInfo];

	[self fetchCategories];
}

- (NSString *) formattedRemainingTime
{
	NSTimeInterval s = self.remainingSeconds;

	if (s <= 0) {
		return @"calculating…";
	}
	else if (s < 60.0) {
		return [NSString stringWithFormat:@"%d seconds remaining", (int)round(s)];
	}
	else if (s < 3600.0) {
		return [NSString stringWithFormat:@"%d minutes remaining", (int)round(s/60.0)];
	}
	else {
		return [NSString stringWithFormat:@"%.1f hours remaining", s/3600.0];
	}
}

- (void) updateSizeField:(NSTimer *)timer
{
	if (!self.latestDownloadedString) return;

	NSString* time_s = [self formattedRemainingTime];
	self.sizeField.stringValue = [NSString stringWithFormat:@"%@ (%@, %@)", kModelDownloadSize, self.latestDownloadedString, time_s];
}

- (void) updatePostsSummaryField
{
	self.numPostsField.hidden = NO;
	if (self.currentPosts.count == 1) {
		self.numPostsField.stringValue = @"1 post";
	}
	else {
		self.numPostsField.stringValue = [NSString stringWithFormat:@"%lu posts", (unsigned long)self.currentPosts.count];
	}
}

- (void) updateCategorizeButton
{
	if (self.selectedCategory) {
		NSString* s = [NSString stringWithFormat:@"🤖 Find Posts for ”%@“", self.selectedCategory.name];
		[self.autoCategorizeButton setTitle:s];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == self.categoriesTable) {
		return self.categories.count;
	}
	else {
		return self.currentPosts.count;
	}
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (tableView == self.categoriesTable) {
		MBEditCategoryCell* cell = [tableView makeViewWithIdentifier:@"EditCategoryCell" owner:self];

		if (row < self.categories.count) {
			MBCategory* c = [self.categories objectAtIndex:row];
			[cell setupWithCategory:c];
		}
		
		return cell;
	}
	else if (tableView == self.postsTable) {
		RFPostCell* cell = [tableView makeViewWithIdentifier:@"PostCell" owner:self];

		if (row < self.currentPosts.count) {
			RFPost* post = [self.currentPosts objectAtIndex:row];
			[(RFPostCell *)cell setupWithPost:post];
		}
		
		return cell;
	}
	else {
		return nil;
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
	if (notification.object == self.categoriesTable) {
		NSInteger row = self.categoriesTable.selectedRow;
		if ((row >= 0) && (row < self.categories.count)) {
			self.selectedCategory = [self.categories objectAtIndex:row];
						
			self.currentPosts = @[];
			[self.postsTable reloadData];
			[self updateCategorizeButton];
			
			[self fetchPostsForCategory];
		}
	}
}

#pragma mark -

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
	if (totalBytesExpectedToWrite <= 0) {
		return;
	}
	
	double progress = ((double)totalBytesWritten / (double)totalBytesExpectedToWrite) * 100.0;
	self.modelProgressBar.doubleValue = progress;
	
	NSString* downloaded_s = [NSByteCountFormatter stringFromByteCount:totalBytesWritten countStyle:NSByteCountFormatterCountStyleFile];
	self.latestDownloadedString = downloaded_s;
	
	if (totalBytesExpectedToWrite > 0) {
		if (self.expectedBytes == 0) self.expectedBytes = totalBytesExpectedToWrite;
		
		NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.downloadStartDate];
		if (elapsed > 0) {
			double bytes_per_second = (double)totalBytesWritten / elapsed;
			if (bytes_per_second > 0) {
				double remaining_bytes = totalBytesExpectedToWrite - totalBytesWritten;
				self.remainingSeconds = remaining_bytes / bytes_per_second;
			}
		}
	}
}

- (void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	if (self.modelDestinationPath) {
		NSURL* dest_url = [NSURL fileURLWithPath:self.modelDestinationPath];
		[[NSFileManager defaultManager] removeItemAtURL:dest_url error:nil];
		[[NSFileManager defaultManager] moveItemAtURL:location toURL:dest_url error:nil];
	}
}

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	[self.modelProgressBar stopAnimation:nil];

	if (error) {
		NSLog(@"Model download failed: %@", error);
		return;
	}

	self.modelProgressBar.doubleValue = 100.0;

	[self.sizeUpdateTimer invalidate];
	self.sizeUpdateTimer = nil;
	self.latestDownloadedString = nil;

	self.downloadTask = nil;
	[self.downloadSession invalidateAndCancel];
	self.downloadSession = nil;

	self.remainingSeconds = 0;
	self.downloadStartDate = nil;
	self.expectedBytes = 0;
	
	[self finishedDownload];
}

@end
