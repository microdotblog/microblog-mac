# Run with: ruby Tests/posts_search_refresh_test.rb
# Exercise production Posts refresh/search methods with controlled responses,
# without loading a nib, accessing an account, or making network requests.
require 'tmpdir'

root = File.expand_path('..', __dir__)
posts = File.read(File.join(root, 'Source/RFAllPostsController.m'))
names = %w[refreshPosts fetchPosts fetchPostsForSearch restoreSelectionForPostURL search postsMatchingSearch closePostingNotification draftDidUpdateNotification]
methods = posts.scan(/^- \([^\n]+\) (?:#{names.join('|')})\b[^;\n]*\n\{.*?^\}/m).join("\n")
abort 'Missing Posts fetch methods' unless methods.include?('existingPosts:(NSArray *)existingPosts')
constants = posts.lines.grep(/^static NSInteger const kRecentPosts/).join

source = <<~OBJC
	#import <Foundation/Foundation.h>
	#define RFDispatchMainAsync(block) block()
	static NSInteger const NSTableViewAnimationEffectNone = 0;
	static NSString* const kCurrentDestinationUID = @"destination";
	#{constants}
	@interface RFPost : NSObject
	@property (copy) NSString* title;
	@property (copy) NSString* text;
	@property (copy) NSString* url;
	@property (copy) NSString* channel;
	@property BOOL scheduled;
	- (instancetype) initFromProperties:(NSDictionary *)properties;
	@end
	@implementation RFPost
	- (instancetype) initFromProperties:(NSDictionary *)properties
	{
		self = [super init];
		if (self) {
			self.title = properties[@"title"] ?: @"";
			self.text = properties[@"text"] ?: @"";
			self.url = properties[@"url"];
			self.scheduled = [properties[@"scheduled"] boolValue];
		}
		return self;
	}
	@end
	@interface TestControl : NSObject
	@property (copy) NSString* stringValue;
	@property BOOL hidden, enabled;
	@property NSInteger stops;
	- (void) stopAnimation:(id)sender;
	@end
	@implementation TestControl
	- (void) stopAnimation:(id)sender { self.stops++; }
	@end
	@interface TestTable : NSObject
	@property (weak) id owner;
	@property NSInteger selectedRow, numberOfRows, reloads, insertions;
	@property double alphaValue;
	- (instancetype) animator;
	- (void) reloadData;
	- (void) insertRowsAtIndexes:(NSIndexSet *)indexes withAnimation:(NSInteger)animation;
	- (void) selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend;
	@end
	@implementation TestTable
	- (instancetype) animator { return self; }
	- (void) reloadData
	{
		self.reloads++;
		self.numberOfRows = [[self.owner valueForKey:@"currentPosts"] count];
		if (self.selectedRow >= self.numberOfRows) { self.selectedRow = -1; }
	}
	- (void) insertRowsAtIndexes:(NSIndexSet *)indexes withAnimation:(NSInteger)animation
	{
		NSCAssert(self.numberOfRows + indexes.count == [[self.owner valueForKey:@"currentPosts"] count], @"Inserted row counts must match displayed results");
		self.numberOfRows += indexes.count;
		self.insertions++;
	}
	- (void) selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend { self.selectedRow = indexes.firstIndex; }
	@end
	@interface RFSettings : NSObject
	+ (NSString *) stringForKey:(NSString *)key;
	@end
	@implementation RFSettings
	+ (NSString *) stringForKey:(NSString *)key { return @"site-a"; }
	@end
	@interface UUHttpResponse : NSObject
	@property (strong) id parsedResponse;
	@property (strong) NSError* httpError;
	@end
	@implementation UUHttpResponse
	@end
	@interface TestRequest : NSObject
	@property (strong) NSDictionary* args;
	@property (copy) void (^completion)(UUHttpResponse*);
	@end
	@implementation TestRequest
	@end
	static NSMutableArray* requests;
	@interface RFClient : NSObject
	- (instancetype) initWithPath:(NSString *)path;
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		NSCAssert([path isEqualToString:@"/micropub"], @"Use the source API");
		return [super init];
	}
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		TestRequest* request = [TestRequest new];
		request.args = args;
		request.completion = handler;
		[requests addObject:request];
	}
	@end
	@interface TestController : NSObject
	@property (strong) NSArray* allPosts;
	@property (strong) NSArray* currentPosts;
	@property (strong) NSArray* scheduledPosts;
	@property (strong) TestTable* tableView;
	@property (strong) TestControl* searchField;
	@property (strong) TestControl* segmentedControl;
	@property (strong) TestControl* progressSpinner;
	@property (strong) TestControl* blogNameButton;
	@property BOOL isShowingDrafts, isShowingScheduled, isShowingPages, isSearching, hasLoadedPosts;
	@property NSInteger postsRequestID, draftFetches;
	- (void) fetchPosts;
	- (void) fetchPostsForSearch:(NSString *)search;
	- (void) fetchPostsForSearch:(NSString *)search limit:(NSInteger)limit offset:(NSInteger)offset existingPosts:(NSArray *)existingPosts requestID:(NSInteger)requestID fetchMore:(BOOL)fetchMore;
	- (void) search:(id)sender;
	- (void) refreshPosts;
	- (void) closePostingNotification:(NSNotification *)notification;
	- (void) draftDidUpdateNotification:(NSNotification *)notification;
	- (NSArray *) postsMatchingSearch:(NSString *)search;
	- (void) restoreSelectionForPostURL:(NSString *)url;
	@end
	@implementation TestController
	- (void) fetchDrafts { self.draftFetches++; }
	- (void) updateSegmentedControlVisibility {}
	- (void) setupBlogName {}
	- (void) updateLoadingSidebarRow {}
	- (void) disableTabs
	{
		self.segmentedControl.enabled = NO;
		self.isShowingDrafts = NO;
		self.isShowingScheduled = NO;
	}
	- (void) updateScheduledPosts
	{
		NSMutableArray* scheduled = [NSMutableArray array];
		for (RFPost* post in self.allPosts) { if (post.scheduled) { [scheduled addObject:post]; } }
		self.scheduledPosts = scheduled;
	}
	#{methods}
	@end
	static NSDictionary* properties(NSString* url, NSString* title)
	{
		return @{ @"url": url, @"title": title, @"text": @"Post contents" };
	}
	static void respond(NSUInteger index, NSArray* properties)
	{
		NSMutableArray* items = [NSMutableArray array];
		for (NSDictionary* item in properties) { [items addObject:@{ @"properties": item }]; }
		UUHttpResponse* response = [UUHttpResponse new];
		response.parsedResponse = @{ @"items": items };
		TestRequest* request = requests[index];
		request.completion(response);
	}
	static TestController* controller(NSString* query)
	{
		TestController* result = [TestController new];
		result.searchField = [TestControl new];
		result.searchField.stringValue = query;
		result.segmentedControl = [TestControl new];
		result.progressSpinner = [TestControl new];
		result.blogNameButton = [TestControl new];
		result.tableView = [TestTable new];
		result.tableView.owner = result;
		result.tableView.alphaValue = 1;
		RFPost* post = [[RFPost alloc] initFromProperties:properties(@"one", @"Coffee books")];
		result.allPosts = @[post];
		result.currentPosts = @[post];
		[result.tableView reloadData];
		return result;
	}
	int main(void)
	{
		@autoreleasepool {
			requests = [NSMutableArray array];
			TestController* posts = controller(@"coffee");
			NSArray* cached_posts = posts.allPosts;
			[posts closePostingNotification:nil];
			TestRequest* request = requests.lastObject;
			NSCAssert([request.args[@"filter"] isEqualToString:@"coffee"] && posts.draftFetches == 1, @"Closing the editor refreshes the active query and drafts");
			NSCAssert(posts.currentPosts.count == 1 && posts.tableView.alphaValue == 1 && posts.isSearching, @"Keep current results visible while refreshing");
			respond(0, @[properties(@"two", @"Coffee earlier"), properties(@"one", @"Coffee edited")]);
			RFPost* edited = posts.currentPosts.lastObject;
			NSCAssert([edited.title isEqualToString:@"Coffee edited"] && posts.tableView.selectedRow == 1, @"Apply the edited result and preserve selection by URL");
			NSCAssert(posts.allPosts == cached_posts && !posts.isSearching && posts.tableView.alphaValue == 1, @"A server search must not replace the recent-post cache");

			for (id invalid in @[[NSNull null], @[], @{ @"error": @"Bad gateway" }, @{ @"items": @"not an array" }]) {
				NSArray* visible = posts.currentPosts;
				[posts refreshPosts];
				UUHttpResponse* response = [UUHttpResponse new];
				response.parsedResponse = invalid;
				[requests.lastObject completion](response);
				NSCAssert(posts.currentPosts == visible && posts.tableView.alphaValue == 1 && !posts.isSearching, @"Malformed responses preserve visible results and finish loading");
			}
			[posts draftDidUpdateNotification:nil];
			UUHttpResponse* failed = [UUHttpResponse new];
			failed.httpError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
			failed.parsedResponse = @{ @"items": @[] };
			[requests.lastObject completion](failed);
			NSCAssert(posts.currentPosts.count == 2 && !posts.isSearching, @"An HTTP or transport failure is not an empty result set");

			[posts refreshPosts];
			NSUInteger stale = requests.count - 1;
			posts.searchField.stringValue = @"updated";
			[posts search:posts.searchField];
			respond(stale, @[]);
			NSCAssert(posts.currentPosts.count == 2 && posts.isSearching, @"An older refresh must not clear a newer search");
			respond(requests.count - 1, @[]);
			NSCAssert(posts.currentPosts.count == 0 && posts.tableView.alphaValue == 1 && !posts.isSearching, @"Genuine zero matches still show an empty result list");

			posts.searchField.stringValue = @"coffee";
			[posts search:posts.searchField];
			stale = requests.count - 1;
			posts.tableView.alphaValue = 0;
			posts.searchField.stringValue = @"";
			[posts search:posts.searchField];
			respond(stale, @[]);
			NSCAssert(posts.currentPosts == cached_posts && posts.tableView.alphaValue == 1 && posts.segmentedControl.enabled, @"Clearing an in-flight search restores visible cached posts");

			TestController* local = controller(@"bo");
			[local search:local.searchField];
			[local closePostingNotification:nil];
			request = requests.lastObject;
			NSCAssert([request.args[@"filter"] isEqualToString:@""] && [request.args[@"limit"] integerValue] == kRecentPostsInitialLimit, @"Short searches refresh the recent-post cache");
			NSMutableArray* page = [NSMutableArray array];
			for (NSInteger i = 0; i < kRecentPostsInitialLimit; i++) {
				[page addObject:properties([NSString stringWithFormat:@"post-%ld", (long)i], i < 3 ? @"Books edited" : @"Unrelated")];
			}
			respond(requests.count - 1, page);
			NSCAssert(local.currentPosts.count == 3 && local.tableView.numberOfRows == 3, @"Reapply the short filter to refreshed posts");
			request = requests.lastObject;
			NSCAssert([request.args[@"offset"] integerValue] == kRecentPostsInitialLimit, @"Continue background pagination with the same request ID");
			respond(requests.count - 1, @[properties(@"older-book", @"Books older"), properties(@"older-other", @"Unrelated")]);
			NSCAssert(local.currentPosts.count == 4 && local.allPosts.count == 17 && local.tableView.insertions == 0, @"Filtered pagination reloads only matching rows, not the raw response count");

			TestController* all = controller(@"");
			[all refreshPosts];
			respond(requests.count - 1, page);
			respond(requests.count - 1, @[properties(@"older", @"Older")]);
			NSCAssert(all.currentPosts.count == 16 && all.tableView.insertions == 1, @"Unfiltered pagination still appends rows normally");
			all.isShowingDrafts = YES;
			[all closePostingNotification:nil];
			NSArray* drafts = all.currentPosts;
			respond(requests.count - 1, @[]);
			NSCAssert(all.currentPosts == drafts, @"Refreshing posts does not clear the selected Drafts tab");
			all.isShowingDrafts = NO;
			all.isShowingScheduled = YES;
			[all refreshPosts];
			respond(requests.count - 1, @[@{ @"url": @"scheduled", @"title": @"Scheduled", @"scheduled": @YES }, properties(@"published", @"Published")]);
			NSCAssert(all.currentPosts.count == 1 && [((RFPost*) all.currentPosts.firstObject).url isEqualToString:@"scheduled"], @"Refresh preserves the Scheduled tab");

			TestController* pages = controller(@"calendar");
			pages.isShowingPages = YES;
			[pages closePostingNotification:nil];
			request = requests.lastObject;
			NSCAssert([request.args[@"mp-channel"] isEqualToString:@"pages"] && [request.args[@"filter"] isEqualToString:@"calendar"], @"Pages also retain their active query");
			respond(requests.count - 1, @[properties(@"page", @"Calendar edited")]);
			NSCAssert(pages.currentPosts.count == 1 && !pages.isSearching, @"Apply matching Pages results without the Posts sidebar spinner");
			NSLog(@"Posts search refresh, short-query pagination, failures, stale responses, tabs, and Pages tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-posts-search-tests-') do |directory|
	path = File.join(directory, 'posts.m')
	binary = File.join(directory, 'posts')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Posts search refresh tests failed' unless system(binary)
end
