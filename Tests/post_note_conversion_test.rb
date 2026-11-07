# Run with: ruby Tests/post_note_conversion_test.rb
# Exercise the production conversion with controlled server responses.
require 'tmpdir'

posts = File.read(File.expand_path('../Source/RFAllPostsController.m', __dir__))
methods = %w[deletePostAtURL draftAtContextMenuRow postToConvertToNote convertPostToNote saveNoteWithText finishPostConversionWithError].map do |name|
	posts[/^- \([^\n]+\) #{name}\b.*?^\}/m] or abort "Missing #{name}"
end.join("\n")
helpers = posts[/^static NSString\* const kPostConversionDidFinishNotification.*?(?=^@interface)/m] or abort 'Missing conversion helpers'

source = <<~'OBJC'
	#import <Foundation/Foundation.h>
	#define dispatch_async(queue, ...) (__VA_ARGS__)()
	#define RFDispatchMainAsync(block) block()
	static NSString* const kRefreshNotesNotification = @"refreshNotes";
	static NSString* const kAccountUsername = @"username";
	static NSString* username = @"test-user";
	static NSString* const kCurrentDestinationUID = @"destination";
	static NSString* destination_uid = @"blog-1";
	static NSString* key = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
	static NSString* encrypted_input;
	static NSString* alert_title;
	@interface RFSettings : NSObject
	+ (NSString *) stringForKey:(NSString *)setting;
	@end
	@implementation RFSettings
	+ (NSString *) stringForKey:(NSString *)setting { return [setting isEqual:kAccountUsername] ? username : destination_uid; }
	@end
	@interface SAMKeychain : NSObject
	+ (NSString *) mb_passwordForService:(NSString *)service account:(NSString *)account;
	@end
	@implementation SAMKeychain
	+ (NSString *) mb_passwordForService:(NSString *)service account:(NSString *)account { return key; }
	@end
	@interface MBNote : NSObject
	+ (BOOL) hasSecretKey;
	+ (NSString *) cleanKey:(NSString *)value;
	+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)value;
	@end
	@implementation MBNote
	+ (BOOL) hasSecretKey { return key != nil; }
	+ (NSString *) cleanKey:(NSString *)value { return value; }
	+ (NSString *) encryptText:(NSString *)text withKey:(NSString *)value { encrypted_input = text; return @"ciphertext"; }
	@end
	@interface RFPost : NSObject
	@property (copy) NSString* url;
	@property (strong) NSNumber* postID;
	@property BOOL isDraft;
	@end
	@implementation RFPost
	@end
	@interface TestTable : NSObject
	@property NSInteger clickedRow, selectedRow;
	@end
	@implementation TestTable
	@end
	@interface NSAlert : NSObject
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler;
	@end
	@implementation NSAlert
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler { alert_title = title; }
	@end
	@interface NSError (NetworkMessage)
	- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response;
	@end
	@implementation NSError (NetworkMessage)
	- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response { return @"Request failed."; }
	@end
	@interface UUHttpResponse : NSObject
	@property (strong) id parsedResponse;
	@property (strong) NSHTTPURLResponse* httpResponse;
	@property (strong) NSError* httpError;
	@end
	@implementation UUHttpResponse
	@end
	static NSMutableArray* requests;
	@interface RFClient : NSObject
	@property (copy) NSString* path;
	@property (copy) NSDictionary* args;
	@property (copy) void (^completion)(UUHttpResponse*);
	- (instancetype) initWithPath:(NSString *)path;
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler;
	- (void) postWithParams:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		self = [super init];
		self.path = path;
		return self;
	}
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert([args[@"q"] isEqual:@"source"], @"Read the latest post source");
		self.args = args;
		self.completion = handler;
		[requests addObject:self];
	}
	- (void) postWithParams:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		self.args = args;
		self.completion = handler;
		[requests addObject:self];
	}
	@end
	static void respond(NSInteger status, id result, NSError* error)
	{
		RFClient* client = requests.lastObject;
		UUHttpResponse* response = [UUHttpResponse new];
		response.parsedResponse = result;
		response.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.test"] statusCode:status HTTPVersion:nil headerFields:nil];
		response.httpError = error;
		client.completion(response);
	}
	__HELPERS__
	@interface TestController : NSObject
	@property BOOL isShowingPages;
	@property (strong) NSArray* currentPosts;
	@property (strong) TestTable* tableView;
	@end
	@implementation TestController
	- (void) updateLoadingSidebarRow {}
	__METHODS__
	@end

	int main(void)
	{
		@autoreleasepool {
			requests = [NSMutableArray array];
			TestController* controller = [TestController new];
			RFPost* post = [RFPost new];
			post.url = @"https://example.test/post";
			post.postID = @24;
			controller.currentPosts = @[post];
			controller.tableView = [TestTable new];
			controller.tableView.clickedRow = 0;
			controller.tableView.selectedRow = -1;
			NSCAssert(![controller draftAtContextMenuRow], @"Hide conversion for posts outside draft status");
			post.isDraft = YES;
			NSString* valid_key = key;
			key = nil;
			NSCAssert([controller draftAtContextMenuRow] == post, @"Keep the draft's menu item visible without a Notes key");
			NSCAssert(![controller postToConvertToNote], @"Require a Notes key");
			key = valid_key;
			controller.isShowingPages = YES;
			NSCAssert(![controller postToConvertToNote], @"Only convert posts");
			controller.isShowingPages = NO;
			NSCAssert([controller postToConvertToNote] == post, @"Convert the right-clicked post");

			NSString* body = @"Original **Markdown**\n\n<img src=\"photo.jpg\">";
			NSDictionary* source = @{ @"properties": @{ @"uid": @[@24], @"name": @[@"Post title"], @"content": @[body], @"post-status": @[@"draft"] } };
			NSDictionary* saved = @{ @"id": @123, @"content_text": @"ciphertext", @"_microblog": @{ @"is_encrypted": @YES } };
			NSDictionary* wrong_post = @{ @"properties": @{ @"uid": @[@25], @"name": @[@"Other post"], @"content": @[body], @"post-status": @[@"draft"] } };
			NSDictionary* published = @{ @"properties": @{ @"uid": @[@24], @"name": @[@"Post title"], @"content": @[body], @"post-status": @[@"published"] } };
			NSDictionary* untitled = @{ @"properties": @{ @"uid": @[@24], @"name": @[[NSNull null]], @"content": @[body], @"post-status": @[@"draft"] } };
			NSCAssert([RFPostNoteText(untitled, @24) isEqual:body], @"Keep untitled posts as plain Markdown");

			for (id result in @[wrong_post, published, @[], @{ @"properties": @{ @"uid": @[@24], @"name": @[@"Title"], @"post-status": @[@"draft"] } }]) {
				[requests removeAllObjects];
				[controller convertPostToNote:post username:username destinationUID:destination_uid];
				respond(200, result, nil);
				NSCAssert(requests.count == 1 && !sConvertingPostToNote, @"Reject unexpected source without writes");
			}
			NSError* lost_connection = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
			for (NSArray* failure in @[
				@[@200, @{ @"id": @123 }, [NSNull null]],
				@[@200, @{ @"id": @123, @"content_text": @"different", @"_microblog": @{ @"is_encrypted": @YES } }, [NSNull null]],
				@[@502, saved, [NSNull null]],
				@[@200, saved, lost_connection]
			]) {
				[requests removeAllObjects];
				[controller convertPostToNote:post username:username destinationUID:destination_uid];
				respond(200, source, nil);
				NSCAssert(requests.count == 2, @"Wait for save result before deleting");
				respond([failure[0] integerValue], failure[1], failure[2] == [NSNull null] ? nil : failure[2]);
				NSCAssert(requests.count == 2 && !sConvertingPostToNote, @"Do not delete or retry an unconfirmed save");
			}
			[requests removeAllObjects];
			[controller convertPostToNote:post username:username destinationUID:destination_uid];
			respond(200, source, nil);
			username = @"other-user";
			respond(200, saved, nil);
			NSCAssert(requests.count == 2 && !sConvertingPostToNote, @"Do not delete from a different account");
			username = @"test-user";

			for (NSNumber* delete_status in @[@200, @502]) {
				[requests removeAllObjects];
				alert_title = nil;
				destination_uid = @"blog-1";
				[controller convertPostToNote:post username:username destinationUID:destination_uid];
				NSCAssert(![controller postToConvertToNote], @"Do not start a second conversion while syncing");
				respond(200, source, nil);
				RFClient* save = requests.lastObject;
				NSCAssert(([save.path isEqual:@"/notes"] && [save.args isEqual:@{ @"text": @"ciphertext", @"is_encrypted": @YES }]), @"Save encrypted text in the default notebook");
				NSCAssert([encrypted_input isEqual:[@"# Post title\n\n" stringByAppendingString:body]], @"Preserve the body under a Markdown heading");
				destination_uid = @"blog-2";
				respond(200, saved, nil);
				RFClient* deletion = requests.lastObject;
				NSCAssert(requests.count == 3 && [deletion.path isEqual:@"/micropub"] && [deletion.args[@"action"] isEqual:@"delete"], @"Delete only after the verified save");
				NSCAssert([deletion.args[@"mp-destination"] isEqual:@"blog-1"] && [deletion.args[@"url"] isEqual:post.url], @"Delete only the original post on its original blog");
				respond(delete_status.integerValue, nil, nil);
				NSCAssert(!sConvertingPostToNote, @"Clear progress after deletion finishes");
				NSCAssert(delete_status.integerValue == 200 ? alert_title == nil : [alert_title isEqual:@"Note Saved"], @"Report partial success on delete failure");
			}
			NSLog(@"Post to note conversion tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-post-note-tests-') do |directory|
	path = File.join(directory, 'conversion.m')
	binary = File.join(directory, 'conversion')
	File.write(path, source.sub('__HELPERS__') { helpers }.sub('__METHODS__') { methods })
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Post conversion tests failed' unless system(binary)
end
