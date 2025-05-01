//
//  MBCategoriesController.m
//  Micro.blog
//
//  Created by Manton Reece on 4/30/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBCategoriesController.h"

static NSString* const kModelDownloadURL = @"https://s3.amazonaws.com/micro.blog/models/gemma-3-4b-it-Q4_K_M.gguf";
static NSString* const kModelDownloadSize = @"2.5 GB";

@implementation MBCategoriesController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"CategoriesWindow"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupInfo];
}

- (void) setupInfo
{
	self.sizeField.stringValue = kModelDownloadSize;
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

- (void) startDownload
{
	NSURL* url = [NSURL URLWithString:kModelDownloadURL];
	
	// build destination path in Application Support/Micro.blog/Models
	NSURL* folder_url = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];

	folder_url = [folder_url URLByAppendingPathComponent:@"Micro.blog" isDirectory:YES];
	folder_url = [folder_url URLByAppendingPathComponent:@"Models" isDirectory:YES];

	[[NSFileManager defaultManager] createDirectoryAtURL:folder_url withIntermediateDirectories:YES attributes:nil error:nil];
	
	NSURL* dest_url = [folder_url URLByAppendingPathComponent:url.lastPathComponent];
	self.modelDestinationPath = dest_url.path;
	
	// configure and show progress bar
	self.progressBar.minValue = 0.0;
	self.progressBar.maxValue = 100.0;
	self.progressBar.doubleValue = 0.0;
	[self.progressBar setHidden:NO];
	[self.progressBar startAnimation:nil];
	
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
	
	[self.progressBar stopAnimation:nil];
	self.progressBar.doubleValue = 0.0;
	[self.progressBar setHidden:YES];
	
	self.sizeField.stringValue = kModelDownloadSize;
	[self.downloadButton setTitle:@"Download"];
	
	self.downloadStartDate = nil;
	self.expectedBytes = 0;
	self.remainingSeconds = 0;
}

- (void) finishedDownload
{
	self.sizeField.stringValue = [NSString stringWithFormat:@"%@ (%@)", kModelDownloadSize, kModelDownloadSize];
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

#pragma mark -

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
	if (totalBytesExpectedToWrite <= 0) {
		return;
	}
	
	double progress = ((double)totalBytesWritten / (double)totalBytesExpectedToWrite) * 100.0;
	self.progressBar.doubleValue = progress;
	
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

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	if (self.modelDestinationPath) {
		NSURL* dest_url = [NSURL fileURLWithPath:self.modelDestinationPath];
		[[NSFileManager defaultManager] removeItemAtURL:dest_url error:nil];
		[[NSFileManager defaultManager] moveItemAtURL:location toURL:dest_url error:nil];
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	[self.progressBar stopAnimation:nil];

	if (error) {
		NSLog(@"Model download failed: %@", error);
		return;
	}

	self.progressBar.doubleValue = 100.0;

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
