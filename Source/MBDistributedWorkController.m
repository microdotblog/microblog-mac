//
//  MBDistributedWorkController.m
//  Micro.blog
//

#import "MBDistributedWorkController.h"

#import "MBRobotsModel.h"
#import "RFConstants.h"
#import "RFClient.h"
#import "RFSettings.h"

#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/ps/IOPowerSources.h>
#import <mach/mach.h>

static NSString* const kDistributedWorkQueuedPath = @"/feeds/work/queued";
static NSString* const kDistributedWorkFinishedPath = @"/feeds/work/finished";
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

			if (![response.parsedResponse isKindOfClass:[NSDictionary class]]) {
				return;
			}

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			if (![items isKindOfClass:[NSArray class]]) {
				return;
			}

			[strong_self.queuedWorkItems removeAllObjects];
			for (id item in items) {
				if ([item isKindOfClass:[NSDictionary class]]) {
					[strong_self.queuedWorkItems addObject:item];
				}
			}

			[strong_self processNextQueuedWorkItem];
		});
	}];
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
//		return NO;
	}

	if ([self idleSeconds] < kDistributedWorkMinimumIdleSeconds) {
//		return NO;
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

	return NO;
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
