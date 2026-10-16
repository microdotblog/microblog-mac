# Run with: ruby Tests/reply_error_handling_test.rb
# Exercise the production reply callbacks and alert helpers with no network,
# account access, nib loading, or modal UI.
require 'tmpdir'

root = File.expand_path('..', __dir__)
posts = File.read(File.join(root, 'Source/RFPostController.m'))
alerts = File.read(File.join(root, 'Source/NSAlert+Extras.m'))
error_method = posts[/^- \(NSString \*\) replyErrorMessageForResponse:.*?^\}/m] or abort 'Missing reply error helper'
reply_method = posts[/^- \(void\) uploadText:.*?(?=^\telse \{\n\t\tNSString\* summary)/m] or abort 'Missing reply callbacks'
alert_methods = alerts[/@implementation NSAlert \(Extras\).*?@end/m] or abort 'Missing alert helpers'

source = <<~OBJC
	#import <Foundation/Foundation.h>
	#import "UUHttpSession.h"
	#import "NSError+Extras.h"
	NSString* const kUUHttpSessionErrorDomain = @"UUHttpSessionErrorDomain";
	NSString* const kUUHttpSessionHttpErrorCodeKey = @"HttpErrorCode";
	@implementation UUHttpResponse
	- (NSString *) description { return @"Test HTTP response"; }
	- (NSString *) debugDescription { return self.description; }
	@end
	typedef NSInteger NSModalResponse;
	static NSMutableArray* main_blocks;
	static BOOL running_ui_block;
	#define RFDispatchMainAsync(block) [main_blocks addObject:[block copy]]
	static void DrainMainBlocks(void)
	{
		while (main_blocks.count > 0) {
			void (^block)(void) = main_blocks.firstObject;
			[main_blocks removeObjectAtIndex:0];
			running_ui_block = YES;
			block();
			running_ui_block = NO;
		}
	}
	@interface NSAlert : NSObject
	@property (copy) NSString* messageText;
	@property (copy) NSString* informativeText;
	@property (strong) NSMutableArray* buttons;
	- (void) addButtonWithTitle:(NSString *)title;
	- (NSModalResponse) runModal;
	@end
	@interface NSAlert (Extras)
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(void (^)(NSModalResponse))handler;
	+ (void) rf_showTwoButtonAlert:(NSString *)title message:(NSString *)message okButton:(NSString *)okButton cancelButton:(NSString *)cancelButton completionHandler:(void (^)(NSModalResponse))handler;
	@end
	static NSAlert* last_alert;
	static NSInteger alert_count;
	@implementation NSAlert
	- (instancetype) init
	{
		NSCAssert(running_ui_block, @"Construct alerts on the main queue, not just runModal");
		self = [super init];
		self.buttons = [NSMutableArray array];
		last_alert = self;
		return self;
	}
	- (void) addButtonWithTitle:(NSString *)title
	{
		NSCAssert([title isKindOfClass:[NSString class]] && title.length > 0, @"Valid button text");
		[self.buttons addObject:title];
	}
	- (NSModalResponse) runModal
	{
		NSCAssert([self.messageText isKindOfClass:[NSString class]] && self.messageText.length > 0, @"Valid title");
		NSCAssert([self.informativeText isKindOfClass:[NSString class]] && self.informativeText.length > 0, @"Valid message, never nil or NSNull");
		alert_count++;
		return 1000;
	}
	@end
	#{alert_methods}
	static UUHttpResponse* next_response;
	static BOOL editing_reply;
	@interface RFClient : NSObject
	- (instancetype) initWithPath:(NSString *)path;
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler;
	- (void) postWithObject:(NSDictionary *)object completion:(void (^)(UUHttpResponse*))handler;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		NSCAssert([path isEqualToString:editing_reply ? @"/micropub" : @"/posts/reply"], @"Correct reply endpoint");
		return [super init];
	}
	- (void) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert([params[@"id"] isEqualToString:@"123"] && [params[@"text"] isEqualToString:@"Reply text"], @"Preserve reply request");
		handler(next_response);
	}
	- (void) postWithObject:(NSDictionary *)object completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert([object[@"action"] isEqualToString:@"update"] && [object[@"replace"][@"content"] isEqualToString:@"Reply text"], @"Preserve edit request");
		handler(next_response);
	}
	@end
	@interface TestPost : NSObject
	@property (copy) NSString* postID;
	@property (copy) NSString* url;
	@end
	@implementation TestPost
	@end
	@interface TestController : NSObject
	@property BOOL isReply, closed, notified, progressHidden;
	@property (strong) TestPost* editingPost;
	@property (copy) NSString* replyPostID;
	- (NSString *) replyErrorMessageForResponse:(UUHttpResponse *)response;
	- (void) uploadText:(NSString *)text;
	- (void) showProgressHeader:(NSString *)text;
	- (void) hideProgressHeader;
	- (void) sendUpdatedReplyNotification;
	- (void) closeWithoutSaving;
	@end
	@implementation TestController
	#{error_method}
	#{reply_method}
	}
	- (void) showProgressHeader:(NSString *)text { self.progressHidden = NO; }
	- (void) hideProgressHeader { self.progressHidden = YES; }
	- (void) sendUpdatedReplyNotification { self.notified = YES; }
	- (void) closeWithoutSaving { self.closed = YES; }
	@end
	static void CheckReply(NSInteger status, id result, NSError* error, NSString* expected)
	{
		for (NSNumber* editing in @[ @NO, @YES ]) {
			editing_reply = editing.boolValue;
			next_response = [UUHttpResponse new];
			if (status > 0) {
				next_response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://micro.blog/posts/reply"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
			}
			next_response.parsedResponse = result;
			next_response.httpError = error;
			TestController* controller = [TestController new];
			controller.isReply = YES;
			controller.replyPostID = @"123";
			if (editing_reply) {
				controller.editingPost = [TestPost new];
				controller.editingPost.postID = @"123";
				controller.editingPost.url = @"https://micro.blog/test/123";
			}
			alert_count = 0;
			[controller uploadText:@"Reply text"];
			DrainMainBlocks();
			if (expected) {
				NSCAssert(alert_count == 1 && [last_alert.informativeText containsString:expected], @"Expected %@, got %@", expected, last_alert.informativeText);
				NSCAssert(controller.progressHidden && !controller.closed && !controller.notified, @"Failures stop progress and preserve the reply");
			}
			else {
				NSCAssert(alert_count == 0 && controller.closed && controller.notified, @"Only successful replies close and refresh");
			}
		}
	}
	int main(void)
	{
		@autoreleasepool {
			main_blocks = [NSMutableArray array];
			for (NSString* message in @[ @"Enable the fediverse in Micro.blog before replying to Mastodon usernames.", @"Connect Bluesky cross-posting in Micro.blog before replying to Bluesky usernames.", @"You need to add a payment method to reply during your Micro.blog trial.", @"Replying disabled." ]) {
				CheckReply(200, @{ @"error": message }, nil, message);
			}
			NSError* http_error = [NSError errorWithDomain:kUUHttpSessionErrorDomain code:UUHttpSessionErrorHttpError userInfo:nil];
			CheckReply(400, @{ @"error": @"invalid_request", @"error_description": @"Posting disabled." }, http_error, @"Posting disabled.");
			for (id value in @[ [NSNull null], @42, @[], @{}, @"", @" \\n" ]) {
				CheckReply(200, @{ @"error": @"Replying disabled.", @"error_description": value }, nil, @"Replying disabled.");
				CheckReply(200, @{ @"error": value }, nil, value == [NSNull null] ? nil : @"The reply could not be sent");
				CheckReply(502, @{ @"error": value, @"error_description": value }, nil, @"HTTP 502");
			}
			for (id result in @[ @"<html>Bad Gateway</html>", @[], @42, [NSNull null] ]) {
				CheckReply(502, result, nil, @"HTTP 502");
				CheckReply(502, result, http_error, @"HTTP 502");
			}
			CheckReply(401, @"Token required", http_error, @"HTTP 401");
			CheckReply(403, nil, nil, @"HTTP 403");
			CheckReply(404, nil, http_error, @"HTTP 404");
			CheckReply(0, nil, nil, @"The reply could not be sent");
			for (NSNumber* code in @[ @(NSURLErrorTimedOut), @(NSURLErrorNotConnectedToInternet) ]) {
				NSError* underlying = [NSError errorWithDomain:NSURLErrorDomain code:code.integerValue userInfo:nil];
				NSError* transport = [NSError errorWithDomain:kUUHttpSessionErrorDomain code:UUHttpSessionErrorHttpFailure userInfo:@{ NSUnderlyingErrorKey: underlying }];
				CheckReply(0, nil, transport, code.integerValue == NSURLErrorTimedOut ? @"timed out" : @"offline");
			}
			CheckReply(200, nil, [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid JSON response." }], @"Invalid JSON response.");
			CheckReply(200, @{}, nil, nil);
			CheckReply(204, nil, nil, nil);

			for (id value in @[ [NSNull null], @42, @[], @{}, @"" ]) {
				__block NSInteger completions = 0;
				[NSAlert rf_showOneButtonAlert:value message:value button:value completionHandler:^(NSModalResponse response) { completions++; }];
				DrainMainBlocks();
				NSCAssert([last_alert.buttons isEqual:@[ @"OK" ]], @"Safe one-button fallback");
				[NSAlert rf_showTwoButtonAlert:value message:value okButton:value cancelButton:value completionHandler:^(NSModalResponse response) { completions++; }];
				DrainMainBlocks();
				NSCAssert(([last_alert.buttons isEqual:@[ @"OK", @"Cancel" ]] && completions == 2), @"Safe two-button fallback and completions");
			}
			[NSAlert rf_showOneButtonAlert:nil message:nil button:nil completionHandler:NULL];
			[NSAlert rf_showTwoButtonAlert:nil message:nil okButton:nil cancelButton:nil completionHandler:NULL];
			DrainMainBlocks();
			NSLog(@"Reply error handling and defensive alert tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-reply-tests-') do |directory|
	path = File.join(directory, 'reply.m')
	binary = File.join(directory, 'reply')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-I', File.join(root, 'Source'), '-I', File.join(root, 'Shared/UUToolbox'), '-framework', 'Foundation', path, File.join(root, 'Source/NSError+Extras.m'), '-o', binary)
	abort 'Reply tests failed' unless system(binary)
end
