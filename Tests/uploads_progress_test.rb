# Run with: ruby Tests/uploads_progress_test.rb
# Exercise production upload queues and progress UI with fake requests and views.
require 'tmpdir'

root = File.expand_path('..', __dir__)
uploads = File.read(File.join(root, 'Source/RFAllUploadsController.m'))
names = %w[uploadFiles uploadNextPhoto uploadPhoto uploadFile activePhotoUploadBatches showUploadProgress hideUploadProgress updatePhotoUploadProgress configureProgressSpinnerForVideoUpload restoreProgressSpinnerAfterVideoUpload]
methods = names.map do |name|
	uploads[/^- \([^\n]+\) #{name}\b[^;\n]*\n\{.*?^\}/m] or abort "Missing #{name}"
end.join("\n")

source = <<~OBJC
	#import <Cocoa/Cocoa.h>
	#import "RFClient.h"
	#define RFDispatchThread(block) block()
	#define RFDispatchMainAsync(block) block()
	static NSString* const kCurrentDestinationUID = @"destination";
	static NSMutableArray* requests;
	static NSInteger alerts;
	static BOOL preparation_fails;
	@interface RFSettings : NSObject
	+ (BOOL) isPremium;
	+ (NSString *) stringForKey:(NSString *)key;
	@end
	@implementation RFSettings
	+ (BOOL) isPremium { return NO; }
	+ (NSString *) stringForKey:(NSString *)key { return @"test-site"; }
	@end
	@interface NSAlert (TestAlerts)
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(void (^)(void))handler;
	@end
	@implementation NSAlert (TestAlerts)
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(void (^)(void))handler { alerts++; }
	@end
	@interface NSString (TestMime)
	- (NSString *) mb_contentType;
	@end
	@implementation NSString (TestMime)
	- (NSString *) mb_contentType { return @"image/png"; }
	@end
	@interface TestImage : NSObject
	- (instancetype) initWithContentsOfFile:(NSString *)path;
	- (instancetype) rf_scaleToSmallestDimension:(CGFloat)dimension;
	@end
	@implementation TestImage
	- (instancetype) initWithContentsOfFile:(NSString *)path { return [path containsString:@"unreadable"] ? nil : [super init]; }
	- (instancetype) rf_scaleToSmallestDimension:(CGFloat)dimension { return self; }
	@end
	#define NSImage TestImage
	@interface RFPhoto : NSObject
	- (instancetype) initWithThumbnail:(NSImage *)image;
	- (NSData *) jpegData;
	@end
	@implementation RFPhoto
	- (instancetype) initWithThumbnail:(NSImage *)image { return [super init]; }
	- (NSData *) jpegData { return preparation_fails ? nil : [@"jpeg" dataUsingEncoding:NSUTF8StringEncoding]; }
	@end
	@implementation UUHttpResponse
	@end
	@interface RFClient ()
	@property (copy) void (^completion)(UUHttpResponse*);
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		NSCAssert([path isEqualToString:@"/micropub/media"], @"Media endpoint");
		return [super init];
	}
	- (UUHttpRequest *) uploadImageData:(NSData *)data named:(NSString *)name filename:(NSString *)filename httpMethod:(NSString *)method queryArguments:(NSDictionary *)args isVideo:(BOOL)video isGIF:(BOOL)gif isPNG:(BOOL)png completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert(self.uploadProgressHandler != nil, @"JPEG progress attached before executing");
		self.completion = handler;
		[requests addObject:self];
		return nil;
	}
	- (UUHttpRequest *) uploadFileData:(NSData *)data named:(NSString *)name filename:(NSString *)filename contentType:(NSString *)mime httpMethod:(NSString *)method queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert(self.uploadProgressHandler != nil, @"PNG/file progress attached before executing");
		self.completion = handler;
		[requests addObject:self];
		return nil;
	}
	@end
	@interface TestIndicator : NSObject
	@property BOOL indeterminate, displayedWhenStopped, hidden;
	@property NSInteger style;
	@property double minValue, maxValue, doubleValue;
	- (void) startAnimation:(id)sender;
	- (void) stopAnimation:(id)sender;
	@end
	@implementation TestIndicator
	- (void) startAnimation:(id)sender {}
	- (void) stopAnimation:(id)sender {}
	@end
	@interface TestController : NSObject
	@property (strong) NSMutableArray* photoUploadProgress;
	@property (readonly) NSInteger activePhotoUploadBatches;
	@property (strong) TestIndicator* progressSpinner;
	@property (strong) TestIndicator* progressCancelButton;
	@property (strong) TestIndicator* blogNameButton;
	@property (strong) NSObject* uploader;
	@property NSInteger refreshes, finishes;
	- (void) uploadFiles:(NSArray *)paths;
	- (void) uploadNextPhoto:(NSMutableArray *)paths progress:(NSProgress *)progress;
	- (void) showUploadProgress:(NSProgress *)progress;
	- (void) hideUploadProgress:(NSProgress *)progress;
	- (void) updatePhotoUploadProgress;
	- (void) configureProgressSpinnerForVideoUpload;
	- (void) restoreProgressSpinnerAfterVideoUpload;
	@end
	@implementation TestController
	- (BOOL) isVideoFileURL:(NSURL *)url { return NO; }
	- (void) uploadVideoURLs:(NSArray *)urls completion:(void (^)(void))handler { handler(); }
	- (BOOL) responseWasSuccessful:(UUHttpResponse *)response { return response.httpError == nil && response.httpResponse.statusCode == 201; }
	- (NSString *) errorMessageForResponse:(UUHttpResponse *)response fallback:(NSString *)fallback { return fallback; }
	- (void) refreshUploadsForCurrentFilter { self.refreshes++; }
	- (void) finishUpload:(NSString *)path { self.finishes++; }
	#{methods}
	@end
	static void advance(NSUInteger index, int64_t sent)
	{
		RFClient* client = requests[index];
		client.uploadProgressHandler(sent, 100);
	}
	static void finish(NSUInteger index, NSInteger status, BOOL location)
	{
		RFClient* client = requests[index];
		UUHttpResponse* response = [UUHttpResponse new];
		response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com/media"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:location ? @{ @"Location": @"https://example.com/photo.jpg" } : @{}];
		if (status == 0) { response.httpError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]; }
		void (^completion)(UUHttpResponse*) = client.completion;
		client.completion = nil;
		completion(response);
	}
	static void expect(TestController* controller, double fraction)
	{
		NSCAssert(!controller.progressSpinner.indeterminate && controller.progressSpinner.style == NSProgressIndicatorStyleBar, @"Determinate photo bar");
		NSCAssert(fabs(controller.progressSpinner.doubleValue - fraction) < 0.001, @"Expected %.3f, got %.3f", fraction, controller.progressSpinner.doubleValue);
		NSCAssert(controller.blogNameButton.hidden && controller.progressCancelButton.hidden, @"Correct controls while uploading photos");
	}
	int main(int argc, const char* argv[])
	{
		@autoreleasepool {
			requests = [NSMutableArray array];
			NSString* png = [NSString stringWithUTF8String:argv[1]];
			TestController* controller = [TestController new];
			controller.progressSpinner = [TestIndicator new];
			controller.progressCancelButton = [TestIndicator new];
			controller.blogNameButton = [TestIndicator new];
			[controller uploadFiles:@[@"photo.jpg", png]];
			expect(controller, 0);
			advance(0, 25);
			expect(controller, 0.125);
			advance(0, 100);
			finish(0, 201, YES);
			expect(controller, 0.5);
			advance(1, 50);
			expect(controller, 0.75);
			advance(1, 100);
			advance(1, 100);
			expect(controller, 1);
			finish(1, 201, YES);
			NSCAssert(controller.activePhotoUploadBatches == 0 && !controller.blogNameButton.hidden && controller.progressSpinner.indeterminate, @"Final completion restores UI");
			NSCAssert(controller.finishes == 2 && controller.refreshes == 1 && alerts == 0, @"Each file finishes once; batch refreshes once");

			[controller uploadFiles:@[@"photo.jpg"]];
			[controller uploadFiles:@[png]];
			advance(2, 60);
			advance(3, 20);
			expect(controller, 0.4);
			[controller configureProgressSpinnerForVideoUpload];
			controller.uploader = [NSObject new];
			controller.progressSpinner.doubleValue = 0.33;
			advance(2, 80);
			NSCAssert(controller.progressSpinner.doubleValue == 0.33 && !controller.progressCancelButton.hidden, @"Photos do not overwrite active video progress");
			controller.uploader = nil;
			[controller restoreProgressSpinnerAfterVideoUpload];
			expect(controller, 0.5);
			finish(2, 502, YES);
			NSCAssert(controller.activePhotoUploadBatches == 1, @"Failure only finishes its own batch");
			expect(controller, 0.2);
			advance(2, 99);
			expect(controller, 0.2);
			advance(3, 100);
			finish(3, 201, YES);

			[controller uploadFiles:@[@"photo.jpg"]];
			finish(4, 201, NO);
			[controller uploadFiles:@[png]];
			finish(5, 0, NO);
			[controller uploadFiles:@[@"unreadable.jpg"]];
			[controller uploadFiles:@[@"unreadable.png"]];
			preparation_fails = YES;
			[controller uploadFiles:@[@"photo.jpg"]];
			NSCAssert(alerts == 6 && controller.activePhotoUploadBatches == 0 && !controller.blogNameButton.hidden, @"HTTP, missing URL, transport, and preparation failures clean up UI");
			NSCAssert(controller.finishes == 3 && controller.refreshes == 2, @"Failed files never count as successful uploads");
			NSLog(@"Uploads progress, overlapping batches, video ownership, and failure cleanup tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-uploads-ui-progress-') do |directory|
	path = File.join(directory, 'progress.m')
	binary = File.join(directory, 'progress')
	fixture = File.join(directory, 'photo.png')
	File.write(path, source)
	File.write(fixture, 'test PNG data')
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-Wno-incomplete-implementation', '-framework', 'Cocoa', '-I', File.join(root, 'Source'), '-I', File.join(root, 'Shared/UUToolbox'), path, '-o', binary)
	abort 'Uploads progress tests failed' unless system(binary, fixture)
end
