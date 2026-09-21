# Run with: ruby Tests/photo_upload_lifecycle_test.rb
# Exercise the production photo upload/removal methods with a fake network client.
require 'tmpdir'

root = File.expand_path('..', __dir__)
photo = File.read(File.join(root, 'Source/RFPhoto.m'))
methods = %w[uploadForAltTextWithCompletion removeUploadWithCompletion].map do |name|
	photo[/^- \(void\) #{name}:.*?^\}/m] or abort "Missing #{name}"
end.join("\n")
source = <<~OBJC
	#import <Foundation/Foundation.h>
	#define RFDispatchMainAsync(block) block()
	@interface UUHttpResponse : NSObject
	@property (strong) NSError* httpError;
	@property (strong) NSHTTPURLResponse* httpResponse;
	@end
	@implementation UUHttpResponse
	@end
	static NSInteger uploads = 0, deletes = 0;
	static void (^pending_upload)(UUHttpResponse*);
	static NSString* deleted_url;
	@interface RFSettings : NSObject
	+ (NSDictionary *) networkingArgsForDestination;
	@end
	@implementation RFSettings
	+ (NSDictionary *) networkingArgsForDestination { return @{}; }
	@end
	@interface RFClient : NSObject
	- (instancetype) initWithPath:(NSString *)path;
	- (void) uploadImageData:(NSData *)data named:(NSString *)name filename:(NSString *)filename httpMethod:(NSString *)method queryArguments:(NSDictionary *)args isVideo:(BOOL)video isGIF:(BOOL)gif isPNG:(BOOL)png completion:(void (^)(UUHttpResponse*))handler;
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path { return [super init]; }
	- (void) uploadImageData:(NSData *)data named:(NSString *)name filename:(NSString *)filename httpMethod:(NSString *)method queryArguments:(NSDictionary *)args isVideo:(BOOL)video isGIF:(BOOL)gif isPNG:(BOOL)png completion:(void (^)(UUHttpResponse*))handler
	{
		uploads++;
		pending_upload = [handler copy];
	}
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler
	{
		deletes++;
		deleted_url = params[@"url"];
		handler([UUHttpResponse new]);
	}
	@end
	@interface RFPhoto : NSObject
	@property BOOL isUploadingForAltText, isGIF, isPNG, isVideo, isUndeletable;
	@property (strong) NSMutableArray* altUploadCompletions;
	@property (strong) NSString* publishedURL;
	@property (strong) NSURL* fileURL;
	- (NSData *) jpegData;
	- (void) uploadForAltTextWithCompletion:(void (^)(BOOL))handler;
	- (void) removeUploadWithCompletion:(void (^)(void))handler;
	@end
	@implementation RFPhoto
	- (NSData *) jpegData { return [@"test image" dataUsingEncoding:NSUTF8StringEncoding]; }
	#{methods}
	@end
	static void finish(NSInteger status)
	{
		UUHttpResponse* response = [UUHttpResponse new];
		response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://micro.blog/micropub/media"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Location": @"https://example.com/photo.jpg" }];
		void (^handler)(UUHttpResponse*) = pending_upload;
		pending_upload = nil;
		handler(response);
	}
	int main(void)
	{
		@autoreleasepool {
			RFPhoto* photo = [RFPhoto new];
			__block NSInteger completions = 0;
			[photo uploadForAltTextWithCompletion:^(BOOL success) { completions++; }];
			[photo uploadForAltTextWithCompletion:^(BOOL success) { completions++; }];
			NSCAssert(uploads == 1 && photo.isUploadingForAltText, @"Reopening joins the existing upload");
			finish(201);
			NSCAssert(completions == 2 && photo.publishedURL.length > 0 && !photo.isUploadingForAltText, @"Success is retained by photo independently of UI");
			[photo uploadForAltTextWithCompletion:^(BOOL success) { NSCAssert(success, @"Reuse uploaded photo"); }];
			NSCAssert(uploads == 1, @"No duplicate upload after completion");
			RFPhoto* removed = [RFPhoto new];
			[removed uploadForAltTextWithCompletion:^(BOOL success) {}];
			__block BOOL removal_finished = NO;
			[removed removeUploadWithCompletion:^{ removal_finished = YES; }];
			NSCAssert(!removal_finished && deletes == 0, @"Removal waits for the upload URL");
			finish(201);
			NSCAssert(removal_finished && deletes == 1 && [deleted_url isEqualToString:removed.publishedURL], @"Delete the completed upload before removing attachment");
			RFPhoto* failed = [RFPhoto new];
			[failed uploadForAltTextWithCompletion:^(BOOL success) { NSCAssert(!success, @"Reject HTTP failure even with Location header"); }];
			finish(502);
			NSCAssert(!failed.isUploadingForAltText && failed.publishedURL == nil, @"Failure clears in-flight state");
			[failed uploadForAltTextWithCompletion:^(BOOL success) { NSCAssert(success, @"Retry can succeed"); }];
			finish(201);
			NSLog(@"Photo upload lifecycle tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-photo-tests-') do |directory|
	path = File.join(directory, 'photo.m')
	binary = File.join(directory, 'photo')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Lifecycle tests failed' unless system(binary)
end
