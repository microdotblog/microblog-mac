//
//  MBDistributedWorkController.m
//  Micro.blog
//

#import "MBDistributedWorkController.h"

#import "MBLogFile.h"
#import "MBRobotsModel.h"
#import "RFConstants.h"
#import "RFClient.h"
#import "RFSettings.h"

#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/ps/IOPowerSources.h>
#import <mach/mach.h>

static NSString* const kDistributedWorkQueuedPath = @"/feeds/work/queued";
static NSString* const kDistributedWorkFinishedPath = @"/feeds/work/finished";
#ifdef DEBUG
static NSString* const kDistributedWorkLocalFilename = @"DistributedWork.json";
#endif
static NSString* const kWorkPromptTypeStatement = @"statement";
static NSString* const kWorkPromptTypeKeywords = @"keywords";
static NSString* const kWorkPromptStatement = @"Write one neutral, third-person sentence stating the main idea of this post. Do not quote the text. Do not use first-person language. Do not start with \"the author\". Avoid adjectives and value judgments.";
static NSString* const kWorkPromptKeywords = @"What are about 10 keywords for this text? Return the keywords only without any punctuation except commas in between each word.";
static NSString* const kWorkPromptFewerKeywords = @"What are about 5 keywords for this text? Return the keywords only without any punctuation except commas in between each word.";
static NSUInteger const kWorkPromptKeywordsMaximumLength = 200;
static NSTimeInterval const kDistributedWorkTimerInterval = 30.0;
static NSTimeInterval const kDistributedWorkTimerTolerance = 5.0;
static NSTimeInterval const kDistributedWorkMinimumIdleSeconds = 60.0;
static double const kDistributedWorkMaximumCPUUsage = 0.20;

@interface MBDistributedWorkController ()

@property (strong, nonatomic, nullable) NSTimer* workTimer;
@property (strong, nonatomic) NSMutableArray<NSDictionary*>* queuedWorkItems;
@property (assign, nonatomic) BOOL isCheckingForWork;
@property (assign, nonatomic) BOOL isProcessingWork;
@property (assign, nonatomic) BOOL hasPreviousCPULoadInfo;
@property (assign, nonatomic) host_cpu_load_info_data_t previousCPULoadInfo;

@end

@implementation MBDistributedWorkController

- (instancetype) init
{
	self = [super init];
	if (self) {
		self.queuedWorkItems = [NSMutableArray array];
	}

	return self;
}

- (void) dealloc
{
	[self stop];
}

- (void) start
{
	if (self.workTimer != nil) {
		return;
	}

	self.workTimer = [NSTimer scheduledTimerWithTimeInterval:kDistributedWorkTimerInterval target:self selector:@selector(checkForWork:) userInfo:nil repeats:YES];
	self.workTimer.tolerance = kDistributedWorkTimerTolerance;
}

- (void) stop
{
	[self.workTimer invalidate];
	self.workTimer = nil;
}

- (void) checkForWork:(nullable id)sender
{
	if (self.isCheckingForWork || self.isProcessingWork) {
		return;
	}

	if (![self hasAccount]) {
		return;
	}

	if (![self canProcessWorkNow]) {
		return;
	}

	self.isCheckingForWork = YES;

#ifdef DEBUG
	if ([self loadLocalWorkFileIfAvailable]) {
		self.isCheckingForWork = NO;
		return;
	}
#endif

	RFClient* client = [[RFClient alloc] initWithPath:kDistributedWorkQueuedPath];
	__weak MBDistributedWorkController* weak_self = self;
	[client getWithCompletion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			MBDistributedWorkController* strong_self = weak_self;
			if (strong_self == nil) {
				return;
			}

			strong_self.isCheckingForWork = NO;

			if (![strong_self isSuccessfulResponse:response]) {
				return;
			}

			[strong_self queueWorkItemsFromParsedResponse:response.parsedResponse];
		});
	}];
}

#ifdef DEBUG
- (BOOL) loadLocalWorkFileIfAvailable
{
	NSString* path = [self localWorkFilePath];
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		return NO;
	}

	NSData* data = [NSData dataWithContentsOfFile:path];
	if (data.length == 0) {
		return YES;
	}

	id parsed_response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	[self queueWorkItemsFromParsedResponse:parsed_response];

	return YES;
}

- (NSString *) localWorkFilePath
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = [paths firstObject];

	NSError* error = nil;
	NSString* microblog_folder = [support_folder stringByAppendingPathComponent:@"Micro.blog"];
	[[NSFileManager defaultManager] createDirectoryAtPath:microblog_folder withIntermediateDirectories:YES attributes:nil error:&error];

	return [microblog_folder stringByAppendingPathComponent:kDistributedWorkLocalFilename];
}
#endif

- (void) queueWorkItemsFromParsedResponse:(id)parsedResponse
{
	NSArray* items = nil;
	if ([parsedResponse isKindOfClass:[NSDictionary class]]) {
		items = [parsedResponse objectForKey:@"items"];
	}
	else if ([parsedResponse isKindOfClass:[NSArray class]]) {
		items = parsedResponse;
	}

	if (![items isKindOfClass:[NSArray class]]) {
		return;
	}

	[self.queuedWorkItems removeAllObjects];
	for (id item in items) {
		if ([item isKindOfClass:[NSDictionary class]]) {
			[self.queuedWorkItems addObject:item];
		}
	}

	[self processNextQueuedWorkItem];
}

- (BOOL) hasAccount
{
	return ([RFSettings stringForKey:kAccountUsername].length > 0);
}

- (BOOL) canProcessWorkNow
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kUseLocalAIModelsPrefKey]) {
		return NO;
	}

	if (![MBRobotsModel isLocalModelAvailable]) {
		return NO;
	}

	if ([NSProcessInfo processInfo].isLowPowerModeEnabled) {
		return NO;
	}

	if (![self isPluggedIntoPower]) {
		return NO;
	}

	if ([self idleSeconds] < kDistributedWorkMinimumIdleSeconds) {
		return NO;
	}

	return [self isCPUUsageLowEnough];
}

- (BOOL) isPluggedIntoPower
{
	CFTypeRef adapter = IOPSCopyExternalPowerAdapterDetails();
	if (adapter != NULL) {
		CFRelease(adapter);
		return YES;
	}

	CFTypeRef power_info = IOPSCopyPowerSourcesInfo();
	if (power_info == NULL) {
		return NO;
	}

	CFStringRef power_type = IOPSGetProvidingPowerSourceType(power_info);
	if ((power_type != NULL) && CFStringCompare(power_type, CFSTR(kIOPMACPowerKey), 0) == kCFCompareEqualTo) {
		CFRelease(power_info);
		return YES;
	}

	CFArrayRef power_sources = IOPSCopyPowerSourcesList(power_info);
	if (power_sources == NULL) {
		CFRelease(power_info);
		return NO;
	}

	BOOL has_power_sources = (CFArrayGetCount(power_sources) > 0);
	CFRelease(power_sources);
	CFRelease(power_info);

	return !has_power_sources;
}

- (NSTimeInterval) idleSeconds
{
	return CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
}

- (BOOL) isCPUUsageLowEnough
{
	host_cpu_load_info_data_t load_info;
	mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
	kern_return_t result = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&load_info, &count);
	if (result != KERN_SUCCESS) {
		return NO;
	}

	if (!self.hasPreviousCPULoadInfo) {
		self.previousCPULoadInfo = load_info;
		self.hasPreviousCPULoadInfo = YES;
		return NO;
	}

	double user = load_info.cpu_ticks[CPU_STATE_USER] - self.previousCPULoadInfo.cpu_ticks[CPU_STATE_USER];
	double system = load_info.cpu_ticks[CPU_STATE_SYSTEM] - self.previousCPULoadInfo.cpu_ticks[CPU_STATE_SYSTEM];
	double nice = load_info.cpu_ticks[CPU_STATE_NICE] - self.previousCPULoadInfo.cpu_ticks[CPU_STATE_NICE];
	double idle = load_info.cpu_ticks[CPU_STATE_IDLE] - self.previousCPULoadInfo.cpu_ticks[CPU_STATE_IDLE];
	double total = user + system + nice + idle;

	self.previousCPULoadInfo = load_info;

	if (total <= 0) {
		return NO;
	}

	double usage = (user + system + nice) / total;
	return (usage <= kDistributedWorkMaximumCPUUsage);
}

- (void) processNextQueuedWorkItem
{
	if (self.isProcessingWork || self.queuedWorkItems.count == 0) {
		return;
	}

	if (![MBRobotsModel isLocalModelAvailable]) {
		return;
	}

	NSDictionary* item = [self.queuedWorkItems firstObject];
	[self.queuedWorkItems removeObjectAtIndex:0];

	NSString* url = [item objectForKey:@"url"];
	if (url.length == 0) {
		[self processNextQueuedWorkItem];
		return;
	}

	__weak MBDistributedWorkController* weak_self = self;
	[self processWork:item url:url completion:^(NSString* text) {
		MBDistributedWorkController* strong_self = weak_self;
		if (strong_self == nil) {
			return;
		}

		[MBLogFile logFields:@[ url, text ?: @"" ] toName:@"Work"];
		[strong_self finishWork:item text:text completion:^{
			strong_self.isProcessingWork = NO;
			[strong_self processNextQueuedWorkItem];
		}];
	}];
}

- (void) processWork:(NSDictionary *)work url:(NSString *)url completion:(void (^)(NSString* text))handler
{
	if (self.isProcessingWork) {
		return;
	}

	self.isProcessingWork = YES;

	NSString* content_text = [self contentTextForWork:work];
	if (content_text != nil) {
		[self processWork:work fetchedText:content_text completion:handler];
		return;
	}

	RFClient* client = [[RFClient alloc] initWithURL:url];
	__weak MBDistributedWorkController* weak_self = self;
	[client getWithCompletion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			MBDistributedWorkController* strong_self = weak_self;
			if (strong_self == nil) {
				return;
			}

			if (![strong_self isSuccessfulResponse:response]) {
				strong_self.isProcessingWork = NO;
				[strong_self processNextQueuedWorkItem];
				return;
			}

			if (![MBRobotsModel isLocalModelAvailable]) {
				strong_self.isProcessingWork = NO;
				[strong_self processNextQueuedWorkItem];
				return;
			}

			NSString* text = [strong_self textFromResponse:response];
			[strong_self processWork:work fetchedText:text completion:handler];
		});
	}];
}

- (nullable NSString *) contentTextForWork:(NSDictionary *)work
{
	NSString* content_text = [work objectForKey:@"content_text"];
	if (![content_text isKindOfClass:[NSString class]]) {
		return nil;
	}

	return content_text;
}

- (BOOL) isSuccessfulResponse:(UUHttpResponse *)response
{
	if (response.httpError != nil) {
		return NO;
	}

	NSInteger status_code = response.httpResponse.statusCode;
	return (status_code >= 200 && status_code < 300);
}

- (void) processWork:(NSDictionary *)work fetchedText:(NSString *)text completion:(void (^)(NSString* text))handler
{
	NSString* prompt_type = [self promptTypeForWork:work];
	if ([prompt_type isEqualToString:kWorkPromptTypeStatement]) {
		[self processStatementWorkWithText:text completion:handler];
		return;
	}
	else if ([prompt_type isEqualToString:kWorkPromptTypeKeywords]) {
		[self processKeywordsWorkWithText:text completion:handler];
		return;
	}

	if (handler) {
		handler(text);
	}
}

- (NSString *) promptTypeForWork:(NSDictionary *)work
{
	NSDictionary* microblog = [work objectForKey:@"_microblog"];
	if (![microblog isKindOfClass:[NSDictionary class]]) {
		return @"";
	}

	NSString* prompt_type = [microblog objectForKey:@"prompt"];
	if (![prompt_type isKindOfClass:[NSString class]]) {
		return @"";
	}

	return prompt_type;
}

- (void) processStatementWorkWithText:(NSString *)text completion:(void (^)(NSString* text))handler
{
	NSString* prompt = [NSString stringWithFormat:@"%@\n\n%@", kWorkPromptStatement, text ?: @""];
	[MBRobotsModel runPrompt:prompt completion:^(NSString* result) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (handler) {
				handler(result ?: @"");
			}
		});
	}];
}

- (void) processKeywordsWorkWithText:(NSString *)text completion:(void (^)(NSString* text))handler
{
	[self runWorkPrompt:kWorkPromptKeywords text:text completion:^(NSString* result) {
		if (result.length <= kWorkPromptKeywordsMaximumLength) {
			if (handler) {
				handler(result);
			}
			return;
		}

		[self runWorkPrompt:kWorkPromptFewerKeywords text:text completion:handler];
	}];
}

- (void) runWorkPrompt:(NSString *)prompt text:(NSString *)text completion:(void (^)(NSString* text))handler
{
	NSString* full_prompt = [NSString stringWithFormat:@"%@\n\n%@", prompt, text ?: @""];
	[MBRobotsModel runPrompt:full_prompt completion:^(NSString* result) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (handler) {
				handler(result ?: @"");
			}
		});
	}];
}

- (NSString *) textFromResponse:(UUHttpResponse *)response
{
	if ([response.parsedResponse isKindOfClass:[NSString class]]) {
		return response.parsedResponse;
	}

	if (response.rawResponse.length > 0) {
		NSString* text = [[NSString alloc] initWithData:response.rawResponse encoding:NSUTF8StringEncoding];
		if (text.length > 0) {
			return text;
		}
	}

	return @"";
}

- (void) finishWork:(NSDictionary *)work text:(NSString *)text completion:(void (^)(void))handler
{
	id work_id_value = [work objectForKey:@"id"];
	NSString* work_id = nil;
	if ([work_id_value isKindOfClass:[NSString class]]) {
		work_id = work_id_value;
	}
	else if ([work_id_value respondsToSelector:@selector(stringValue)]) {
		work_id = [work_id_value stringValue];
	}

	if (work_id.length == 0) {
		if (handler) {
			handler();
		}
		return;
	}

	RFClient* client = [[RFClient alloc] initWithPath:kDistributedWorkFinishedPath];
	NSDictionary* args = @{
		@"id": work_id,
		@"text": text ?: @""
	};

	[client postWithParams:args completion:^(UUHttpResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (handler) {
				handler();
			}
		});
	}];
}

@end
