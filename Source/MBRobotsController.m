//
//  MBRobotsController.m
//  Micro.blog
//

#import "MBRobotsController.h"

#import "MBRobotsModel.h"

#import <sys/sysctl.h>

static uint64_t const kMinimumMemoryBytes = 24ULL * 1024ULL * 1024ULL * 1024ULL;

@interface MBRobotsController () <NSURLSessionDataDelegate>

@property (strong, nonatomic) NSURLSession* session;
@property (strong, nonatomic, nullable) NSURLSessionDataTask* currentTask;
@property (strong, nonatomic, nullable) NSFileHandle* currentFileHandle;
@property (copy, nonatomic, nullable) NSString* currentFilename;
@property (copy, nonatomic, nullable) NSString* currentTemporaryPath;
@property (assign, nonatomic) long long currentExpectedBytes;
@property (assign, nonatomic) long long currentReceivedBytes;
@property (assign, nonatomic) NSInteger currentLargeIndex;
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
	return [self hasAppleSilicon] && [self hasRequiredMemory];
}

+ (BOOL) hasRequiredMemory
{
	return [NSProcessInfo processInfo].physicalMemory >= kMinimumMemoryBytes;
}

+ (BOOL) hasAppleSilicon
{
	int arm64_supported = 0;
	size_t size = sizeof(arm64_supported);
	if (sysctlbyname("hw.optional.arm64", &arm64_supported, &size, NULL, 0) == 0) {
		return arm64_supported == 1;
	}

#if defined(__arm64__) || defined(__aarch64__)
	return YES;
#else
	return NO;
#endif
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
	self.currentLargeIndex = 0;

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

	[self downloadNextFile];
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
		if ([[MBRobotsModel largeModelFilenames] containsObject:filename]) {
			self.currentLargeIndex += 1;
		}
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

	NSString* escaped_filename = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
	NSURL* url = [NSURL URLWithString:[MBRobotsModelBaseURLString stringByAppendingString:escaped_filename]];
	self.currentTask = [self.session dataTaskWithURL:url];
	self.currentExpectedBytes = 0;
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

	BOOL is_large_file = [[MBRobotsModel largeModelFilenames] containsObject:self.currentFilename];
	if (!is_large_file) {
		[self postProgressIndeterminate:YES progress:0.0 status:@"Downloading model files..." detail:@""];
		return;
	}

	NSInteger total_large_files = [MBRobotsModel largeModelFilenames].count;
	double file_progress = 0.0;
	if (self.currentExpectedBytes > 0) {
		file_progress = (double)self.currentReceivedBytes / (double)self.currentExpectedBytes;
	}
	double total_progress = ((double)self.currentLargeIndex + file_progress) / (double)total_large_files;
	NSString* detail = [NSString stringWithFormat:@"%ld of %ld large files", (long)(self.currentLargeIndex + 1), (long)total_large_files];
	[self postProgressIndeterminate:NO progress:total_progress status:@"Downloading local model..." detail:detail];
}

- (void) postProgressIndeterminate:(BOOL)indeterminate progress:(double)progress status:(NSString *)status detail:(NSString *)detail
{
	MBRobotsDownloadProgressBlock block = self.progressBlock;
	if (block == nil) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		block(indeterminate, progress, status, detail);
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
	self.currentExpectedBytes = 0;
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

	self.currentExpectedBytes = response.expectedContentLength;
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
	BOOL is_large_file = [[MBRobotsModel largeModelFilenames] containsObject:self.currentFilename];

	[self.currentFileHandle closeFile];
	self.currentFileHandle = nil;
	self.currentFilename = nil;
	self.currentTemporaryPath = nil;
	self.currentExpectedBytes = 0;
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

	if (is_large_file) {
		self.currentLargeIndex += 1;
	}

	[self downloadNextFile];
}

@end
