//
//  MBRobotsController.m
//  Micro.blog
//

#import "MBRobotsController.h"

#import "MBRobotsModel.h"

#import <math.h>

static uint64_t const kBytesPerGB = 1024ULL * 1024 * 1024;
static uint64_t const kMinimumMemoryBytes = 24 * kBytesPerGB;
static uint64_t const kMinimumStorageBytes = 20 * kBytesPerGB;

@interface MBRobotsController () <NSURLSessionDataDelegate>

@property (strong, nonatomic) NSURLSession* session;
@property (strong, nonatomic, nullable) NSURLSessionDataTask* currentTask;
@property (strong, nonatomic, nullable) NSFileHandle* currentFileHandle;
@property (copy, nonatomic, nullable) NSString* currentFilename;
@property (copy, nonatomic, nullable) NSString* currentTemporaryPath;
@property (strong, nonatomic, nullable) NSDate* downloadStartDate;
@property (strong, nonatomic) NSDictionary<NSString *, NSNumber *>* expectedContentLengthsByFilename;
@property (assign, nonatomic) long long totalExpectedBytes;
@property (assign, nonatomic) long long completedExpectedBytes;
@property (assign, nonatomic) long long receivedBytesThisRun;
@property (assign, nonatomic) long long currentReceivedBytes;
@property (strong, nonatomic) NSArray<NSString *>* pendingFilenames;
@property (copy, nonatomic, nullable) MBRobotsDownloadProgressBlock progressBlock;
@property (copy, nonatomic, nullable) MBRobotsDownloadCompletionBlock completionBlock;
@property (strong, nonatomic, nullable) NSError* currentError;
@property (assign, nonatomic, readwrite) BOOL isDownloading;
@property (assign, nonatomic) BOOL isCancelling;

@end

@implementation MBRobotsController

- (instancetype) init
{
	self = [super init];
	if (self) {
		NSOperationQueue* queue = [[NSOperationQueue alloc] init];
		queue.maxConcurrentOperationCount = 1;
		NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
		self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];
		self.pendingFilenames = @[];
		self.expectedContentLengthsByFilename = @{};
	}

	return self;
}

- (void) dealloc
{
	[self cancelDownload];
	[self.session invalidateAndCancel];
}

+ (BOOL) isSupportedMachine
{
	return [self hasSupportedHardware] && [self hasRequiredStorage];
}

+ (BOOL) hasSupportedHardware
{
	return [MBRobotsModel isLocalModelSupported] && [self hasRequiredMemory];
}

+ (BOOL) hasRequiredMemory
{
	return [NSProcessInfo processInfo].physicalMemory >= kMinimumMemoryBytes;
}

+ (BOOL) hasRequiredStorage
{
	NSNumber* available_storage = [self availableStorageBytes];
	return (available_storage != nil) && (available_storage.unsignedLongLongValue >= kMinimumStorageBytes);
}

+ (NSNumber *) availableStorageBytes
{
	NSArray<NSURL *>* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	NSURL* app_support_url = urls.firstObject;
	if (app_support_url == nil) {
		app_support_url = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
	}

	NSError* error = nil;
	NSDictionary<NSURLResourceKey, id>* values = [app_support_url resourceValuesForKeys:@[
		NSURLVolumeAvailableCapacityForImportantUsageKey,
		NSURLVolumeAvailableCapacityKey
	] error:&error];
	NSNumber* available_storage = values[NSURLVolumeAvailableCapacityForImportantUsageKey];
	if (available_storage == nil) {
		available_storage = values[NSURLVolumeAvailableCapacityKey];
	}

	return available_storage;
}

- (void) startDownloadingModelWithProgress:(MBRobotsDownloadProgressBlock)progressBlock completion:(MBRobotsDownloadCompletionBlock)completionBlock
{
	if (self.isDownloading) {
		return;
	}

	self.progressBlock = progressBlock;
	self.completionBlock = completionBlock;
	self.isDownloading = YES;
	self.isCancelling = NO;
	self.totalExpectedBytes = 0;
	self.completedExpectedBytes = 0;
	self.receivedBytesThisRun = 0;
	self.expectedContentLengthsByFilename = @{};
	[self postProgressIndeterminate:NO progress:0.0 detail:@""];

	if (![MBRobotsController isSupportedMachine]) {
		[self finishWithSuccess:NO cancelled:NO error:nil];
		return;
	}

	if ([MBRobotsModel isLocalModelAvailable]) {
		[self finishWithSuccess:YES cancelled:NO error:nil];
		return;
	}

	NSError* folder_error = nil;
	NSString* model_folder = [MBRobotsModel localModelFolderPath];
	if (model_folder.length == 0 || ![[NSFileManager defaultManager] createDirectoryAtPath:model_folder withIntermediateDirectories:YES attributes:nil error:&folder_error]) {
		[self finishWithSuccess:NO cancelled:NO error:folder_error];
		return;
	}

	NSMutableArray<NSString *>* filenames = [NSMutableArray array];
	for (NSString* filename in [MBRobotsModel modelFilenames]) {
		if (![[MBRobotsModel largeModelFilenames] containsObject:filename]) {
			[filenames addObject:filename];
		}
	}
	[filenames addObjectsFromArray:[MBRobotsModel largeModelFilenames]];
	self.pendingFilenames = filenames;

	[self loadExpectedContentLengthsForFilenames:filenames];
}

- (void) cancelDownload
{
	if (!self.isDownloading) {
		return;
	}

	self.isCancelling = YES;
	[self.currentTask cancel];
	[self cleanupCurrentDownload];
	[self finishWithSuccess:NO cancelled:YES error:nil];
}

- (void) loadExpectedContentLengthsForFilenames:(NSArray<NSString *> *)filenames
{
	[self loadExpectedContentLengthsForFilenames:filenames index:0 sizes:[NSMutableDictionary dictionary] totalBytes:0];
}

- (void) loadExpectedContentLengthsForFilenames:(NSArray<NSString *> *)filenames index:(NSInteger)index sizes:(NSMutableDictionary<NSString *, NSNumber *> *)sizes totalBytes:(long long)totalBytes
{
	if (self.isCancelling) {
		return;
	}

	if (index >= filenames.count) {
		self.expectedContentLengthsByFilename = sizes;
		self.totalExpectedBytes = totalBytes;
		self.downloadStartDate = [NSDate date];
		[self postProgressIndeterminate:NO progress:0.0 detail:@""];
		[self downloadNextFile];
		return;
	}

	NSString* filename = filenames[index];
	NSURL* url = [self urlForFilename:filename];
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
	request.HTTPMethod = @"HEAD";

	__weak MBRobotsController* weak_self = self;
	self.currentTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
		MBRobotsController* strong_self = weak_self;
		if (strong_self == nil || strong_self.isCancelling) {
			return;
		}

		if (error) {
			[strong_self finishWithSuccess:NO cancelled:NO error:error];
			return;
		}

		NSHTTPURLResponse* http_response = (NSHTTPURLResponse *)response;
		if ([http_response isKindOfClass:[NSHTTPURLResponse class]] && (http_response.statusCode < 200 || http_response.statusCode >= 300)) {
			NSError* http_error = [NSError errorWithDomain:NSURLErrorDomain code:http_response.statusCode userInfo:@{ NSLocalizedDescriptionKey: @"Could not check the model file size." }];
			[strong_self finishWithSuccess:NO cancelled:NO error:http_error];
			return;
		}

		long long expected_length = response.expectedContentLength;
		if (expected_length <= 0) {
			NSString* content_length = http_response.allHeaderFields[@"Content-Length"];
			expected_length = content_length.longLongValue;
		}
		if (expected_length <= 0) {
			NSError* length_error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{ NSLocalizedDescriptionKey: @"The model file size is missing." }];
			[strong_self finishWithSuccess:NO cancelled:NO error:length_error];
			return;
		}

		sizes[filename] = @(expected_length);
		strong_self.currentTask = nil;
		[strong_self loadExpectedContentLengthsForFilenames:filenames index:(index + 1) sizes:sizes totalBytes:(totalBytes + expected_length)];
	}];
	[self.currentTask resume];
}

- (void) downloadNextFile
{
	if (self.pendingFilenames.count == 0) {
		[self finishWithSuccess:[MBRobotsModel isLocalModelAvailable] cancelled:NO error:nil];
		return;
	}

	NSString* filename = self.pendingFilenames.firstObject;
	self.pendingFilenames = [self.pendingFilenames subarrayWithRange:NSMakeRange(1, self.pendingFilenames.count - 1)];
	self.currentFilename = filename;

	NSString* destination_path = [[MBRobotsModel localModelFolderPath] stringByAppendingPathComponent:filename];
	BOOL is_directory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:destination_path isDirectory:&is_directory] && !is_directory) {
		self.completedExpectedBytes += [self expectedLengthForFilename:filename];
		[self postProgressForCurrentFile];
		[self downloadNextFile];
		return;
	}

	self.currentTemporaryPath = [destination_path stringByAppendingString:@".download"];
	[self removeFileAtPathIfExists:self.currentTemporaryPath];
	if (![[NSFileManager defaultManager] createFileAtPath:self.currentTemporaryPath contents:nil attributes:nil]) {
		NSError* error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{ NSLocalizedDescriptionKey: @"Could not create the temporary model file." }];
		[self finishWithSuccess:NO cancelled:NO error:error];
		return;
	}
	self.currentFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.currentTemporaryPath];
	if (self.currentFileHandle == nil) {
		NSError* error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{ NSLocalizedDescriptionKey: @"Could not open the temporary model file." }];
		[self finishWithSuccess:NO cancelled:NO error:error];
		return;
	}

	NSURL* url = [self urlForFilename:filename];
	self.currentTask = [self.session dataTaskWithURL:url];
	self.currentReceivedBytes = 0;
	self.currentError = nil;

	[self postProgressForCurrentFile];
	[self.currentTask resume];
}

- (void) postProgressForCurrentFile
{
	if (self.progressBlock == nil || self.currentFilename.length == 0) {
		return;
	}

	double total_progress = 0.0;
	if (self.totalExpectedBytes > 0) {
		long long downloaded_bytes = self.completedExpectedBytes + self.currentReceivedBytes;
		total_progress = (double)downloaded_bytes / (double)self.totalExpectedBytes;
	}
	NSString* detail = [self estimatedTimeRemainingString];
	[self postProgressIndeterminate:NO progress:total_progress detail:detail];
}

- (NSString *) estimatedTimeRemainingString
{
	if (self.totalExpectedBytes <= 0 || self.receivedBytesThisRun <= 0 || self.downloadStartDate == nil) {
		return @"";
	}

	NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.downloadStartDate];
	if (elapsed < 2.0) {
		return @"";
	}

	double bytes_per_second = (double)self.receivedBytesThisRun / elapsed;
	if (bytes_per_second <= 0.0) {
		return @"";
	}

	long long remaining_bytes = MAX(0LL, self.totalExpectedBytes - self.completedExpectedBytes - self.currentReceivedBytes);
	NSTimeInterval seconds_remaining = (double)remaining_bytes / bytes_per_second;
	return [self formattedTimeRemaining:seconds_remaining];
}

- (NSURL *) urlForFilename:(NSString *)filename
{
	NSString* escaped_filename = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
	return [NSURL URLWithString:[MBRobotsModelBaseURLString stringByAppendingString:escaped_filename]];
}

- (long long) expectedLengthForFilename:(NSString *)filename
{
	return self.expectedContentLengthsByFilename[filename].longLongValue;
}

- (NSString *) formattedTimeRemaining:(NSTimeInterval)secondsRemaining
{
	if (secondsRemaining < 60.0) {
		NSInteger seconds = MAX(1, (NSInteger)ceil(secondsRemaining));
		NSString* unit = (seconds == 1) ? @"second" : @"seconds";
		return [NSString stringWithFormat:@"%ld %@ remaining", (long)seconds, unit];
	}
	else if (secondsRemaining < 60.0 * 60.0) {
		NSInteger minutes = MAX(1, (NSInteger)ceil(secondsRemaining / 60.0));
		NSString* unit = (minutes == 1) ? @"minute" : @"minutes";
		return [NSString stringWithFormat:@"%ld %@ remaining", (long)minutes, unit];
	}
	else {
		double hours = secondsRemaining / (60.0 * 60.0);
		return [NSString stringWithFormat:@"%.1f hours remaining", hours];
	}
}

- (void) postProgressIndeterminate:(BOOL)indeterminate progress:(double)progress detail:(NSString *)detail
{
	MBRobotsDownloadProgressBlock block = self.progressBlock;
	if (block == nil) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		block(indeterminate, progress, detail);
	});
}

- (void) finishWithSuccess:(BOOL)success cancelled:(BOOL)cancelled error:(NSError *)error
{
	if (!self.isDownloading) {
		return;
	}

	self.isDownloading = NO;
	self.isCancelling = NO;
	self.currentTask = nil;
	self.pendingFilenames = @[];
	self.expectedContentLengthsByFilename = @{};
	self.totalExpectedBytes = 0;
	self.completedExpectedBytes = 0;
	self.receivedBytesThisRun = 0;
	self.downloadStartDate = nil;
	[self cleanupCurrentDownload];

	MBRobotsDownloadCompletionBlock block = self.completionBlock;
	self.progressBlock = nil;
	self.completionBlock = nil;

	if (block) {
		dispatch_async(dispatch_get_main_queue(), ^{
			block(success, cancelled, error);
		});
	}
}

- (void) cleanupCurrentDownload
{
	[self.currentFileHandle closeFile];
	self.currentFileHandle = nil;

	if (self.currentTemporaryPath.length > 0) {
		[self removeFileAtPathIfExists:self.currentTemporaryPath];
	}

	self.currentFilename = nil;
	self.currentTemporaryPath = nil;
	self.currentReceivedBytes = 0;
	self.currentError = nil;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
	NSHTTPURLResponse* http_response = (NSHTTPURLResponse *)response;
	if ([http_response isKindOfClass:[NSHTTPURLResponse class]] && (http_response.statusCode < 200 || http_response.statusCode >= 300)) {
		self.currentError = [NSError errorWithDomain:NSURLErrorDomain code:http_response.statusCode userInfo:@{ NSLocalizedDescriptionKey: @"Could not download the model file." }];
		completionHandler(NSURLSessionResponseCancel);
		return;
	}

	completionHandler(NSURLSessionResponseAllow);
}

- (void) removeFileAtPathIfExists:(NSString *)path
{
	if (path.length == 0) {
		return;
	}

	BOOL is_directory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&is_directory] && !is_directory) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	@try {
		[self.currentFileHandle writeData:data];
	}
	@catch (NSException* exception) {
		self.currentError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{ NSLocalizedDescriptionKey: exception.reason ?: @"Could not write the model file." }];
		[self.currentTask cancel];
		return;
	}
	self.currentReceivedBytes += data.length;
	self.receivedBytesThisRun += data.length;
	[self postProgressForCurrentFile];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	if (self.isCancelling) {
		return;
	}

	NSError* finished_error = self.currentError ?: error;
	if (finished_error) {
		[self cleanupCurrentDownload];
		[self finishWithSuccess:NO cancelled:NO error:finished_error];
		return;
	}

	NSString* destination_path = [[MBRobotsModel localModelFolderPath] stringByAppendingPathComponent:self.currentFilename];
	NSString* temporary_path = self.currentTemporaryPath;
	long long expected_length = [self expectedLengthForFilename:self.currentFilename];

	[self.currentFileHandle closeFile];
	self.currentFileHandle = nil;
	self.currentFilename = nil;
	self.currentTemporaryPath = nil;
	self.currentReceivedBytes = 0;

	BOOL is_directory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:destination_path isDirectory:&is_directory]) {
		if (is_directory) {
			NSError* error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError userInfo:@{ NSLocalizedDescriptionKey: @"A folder already exists where the model file should be saved." }];
			[self removeFileAtPathIfExists:temporary_path];
			[self finishWithSuccess:NO cancelled:NO error:error];
			return;
		}
		[self removeFileAtPathIfExists:destination_path];
	}

	NSError* move_error = nil;
	if (![[NSFileManager defaultManager] moveItemAtPath:temporary_path toPath:destination_path error:&move_error]) {
		[self removeFileAtPathIfExists:temporary_path];
		[self finishWithSuccess:NO cancelled:NO error:move_error];
		return;
	}

	self.completedExpectedBytes += expected_length;
	[self postProgressForCurrentFile];

	[self downloadNextFile];
}

@end
