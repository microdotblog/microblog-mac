//
//  MBRobotsModel.m
//  Micro.blog
//

#import "MBRobotsModel.h"

#import "Micro_blog-Swift.h"

NSString* const MBRobotsModelBaseURLString = @"https://s3.amazonaws.com/micro.blog/models/gemma-4/";

@implementation MBRobotsModel

- (instancetype) initWithModelFolderPath:(NSString *)modelFolderPath
{
	self = [super init];
	if (self) {
		self.modelFolderPath = modelFolderPath;
	}

	return self;
}

+ (NSArray<NSString *> *) modelFilenames
{
	return @[
		@"config.json",
		@"model-00001-of-00003.safetensors",
		@"model-00002-of-00003.safetensors",
		@"model-00003-of-00003.safetensors",
		@"tokenizer.json",
		@"tokenizer_config.json"
	];
}

+ (NSArray<NSString *> *) largeModelFilenames
{
	return @[
		@"model-00001-of-00003.safetensors",
		@"model-00002-of-00003.safetensors",
		@"model-00003-of-00003.safetensors"
	];
}

+ (NSString *) localModelFolderPath
{
	NSArray<NSURL *>* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	NSURL* app_support_url = urls.firstObject;
	if (app_support_url == nil) {
		return @"";
	}

	NSURL* model_url = [app_support_url URLByAppendingPathComponent:@"Micro.blog" isDirectory:YES];
	model_url = [model_url URLByAppendingPathComponent:@"Models" isDirectory:YES];
	model_url = [model_url URLByAppendingPathComponent:@"Gemma 4" isDirectory:YES];
	return model_url.path;
}

+ (BOOL) isLocalModelAvailable
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* model_folder = [self localModelFolderPath];
	if (model_folder.length == 0) {
		return NO;
	}

	for (NSString* filename in [self modelFilenames]) {
		NSString* path = [model_folder stringByAppendingPathComponent:filename];
		BOOL is_directory = NO;
		if (![fm fileExistsAtPath:path isDirectory:&is_directory] || is_directory) {
			return NO;
		}
	}

	return YES;
}

+ (unsigned long long) localModelStorageBytes
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* model_folder = [self localModelFolderPath];
	if (model_folder.length == 0) {
		return 0;
	}

	unsigned long long total_bytes = 0;
	for (NSString* filename in [self modelFilenames]) {
		NSString* path = [model_folder stringByAppendingPathComponent:filename];
		BOOL is_directory = NO;
		if (![fm fileExistsAtPath:path isDirectory:&is_directory] || is_directory) {
			continue;
		}

		NSDictionary<NSFileAttributeKey, id>* attributes = [fm attributesOfItemAtPath:path error:NULL];
		total_bytes += [attributes[NSFileSize] unsignedLongLongValue];
	}

	return total_bytes;
}

+ (void) runPrompt:(NSString *)string completion:(void (^)(NSString* result))completion
{
	if (![self isLocalModelAvailable]) {
		completion(@"");
		return;
	}

	[MBRobotsPromptRunner runPrompt:string modelFolderPath:[self localModelFolderPath] completion:^(NSString* result) {
		completion(result ?: @"");
	}];
}

+ (void) preloadModelWithCompletion:(void (^)(BOOL success))completion
{
	if (![self isLocalModelAvailable]) {
		completion(NO);
		return;
	}

	[MBRobotsPromptRunner preloadModelWithModelFolderPath:[self localModelFolderPath] completion:completion];
}

+ (void) deleteLocalModelFiles
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSString* model_folder = [self localModelFolderPath];
	if (model_folder.length == 0) {
		return;
	}

	for (NSString* filename in [self modelFilenames]) {
		NSString* path = [model_folder stringByAppendingPathComponent:filename];
		BOOL is_directory = NO;
		if ([fm fileExistsAtPath:path isDirectory:&is_directory] && !is_directory) {
			[fm removeItemAtPath:path error:NULL];
		}
	}
}

@end
