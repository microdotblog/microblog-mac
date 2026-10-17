# Run with: ruby Tests/uploads_background_check_test.rb
# Exercise the production polling and metadata updates without networking or UI.
require 'tmpdir'

root = File.expand_path('..', __dir__)
uploads = File.read(File.join(root, 'Source/RFAllUploadsController.m'))
info = File.read(File.join(root, 'Source/MBInfoController.m'))
names = %w[startUploadsTimer uploadsCheckInterval didFinishUpload invalidateUploadsTimer checkForNewUploads updateAccessibilityTextForUploads]
methods = names.map do |name|
	uploads[/^- \([^\n]+\) #{name}\b[^;\n]*\n\{.*?^\}/m] or abort "Missing #{name}"
end.join("\n")
info_method = info[/^- \(void\) updateInfoNotification:.*?^\}/m] or abort 'Missing Info update handler'
finish = uploads[/^- \(void\) finishUpload:.*?^\}/m] or abort 'Missing upload completion'
abort 'Photo/file completion must reset polling' unless finish.include?('[self didFinishUpload]')
abort 'Video completion must reset polling' unless uploads.include?('[innerSelf didFinishUpload]')
constants = uploads.lines.grep(/^static .*const k(InitialUploadsLimit|UploadsCheckInterval|RecentUploadsCheckInterval|RecentUploadsCheckDuration)\b/).join

source = <<~OBJC
	#import <Foundation/Foundation.h>
	#import "RFConstants.h"
	#define RFDispatchMainAsync(block) block()
	static NSString* const kCurrentDestinationUID = @"CurrentDestinationUID";
	#{constants}
	@interface NSIndexPath (CollectionItems)
	+ (instancetype) indexPathForItem:(NSUInteger)item inSection:(NSUInteger)section;
	@property (readonly) NSUInteger item;
	@end
	@implementation NSIndexPath (CollectionItems)
	+ (instancetype) indexPathForItem:(NSUInteger)item inSection:(NSUInteger)section
	{
		NSUInteger indexes[] = { section, item };
		return [self indexPathWithIndexes:indexes length:2];
	}
	- (NSUInteger) item { return [self indexAtPosition:1]; }
	@end
	@interface RFUpload : NSObject
	@property (copy) NSString* url;
	@property (copy) NSString* alt;
	@property BOOL isAI;
	@property (strong) NSObject* cachedImage;
	@end
	@implementation RFUpload
	@end
	@interface RFPhotoCell : NSObject
	@property (copy) NSString* alt;
	@property BOOL isAI;
	@end
	@implementation RFPhotoCell
	@end
	@interface TestCollection : NSObject
	@property (strong) NSDictionary* cells;
	- (id) itemAtIndexPath:(NSIndexPath *)path;
	@end
	@implementation TestCollection
	- (id) itemAtIndexPath:(NSIndexPath *)path { return self.cells[@(path.item)]; }
	@end
	static NSString* destination = @"site-a";
	@interface RFSettings : NSObject
	+ (NSString *) stringForKey:(NSString *)key;
	@end
	@implementation RFSettings
	+ (NSString *) stringForKey:(NSString *)key { return destination; }
	@end
	@interface UUHttpResponse : NSObject
	@property (strong) NSArray* uploads;
	@end
	@implementation UUHttpResponse
	@end
	static NSInteger requests;
	static NSDictionary* last_args;
	static void (^pending_response)(UUHttpResponse*);
	@interface RFClient : NSObject
	- (instancetype) initWithPath:(NSString *)path;
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		NSCAssert([path isEqualToString:@"/micropub/media"], @"Correct metadata endpoint");
		return [super init];
	}
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))handler
	{
		NSCAssert(pending_response == nil, @"No overlapping checks");
		requests++;
		last_args = args;
		pending_response = [handler copy];
	}
	@end
	@interface TestController : NSObject
	@property (strong) NSArray* allPosts;
	@property (strong) TestCollection* collectionView;
	@property (strong) NSDate* lastUploadFinishedAt;
	@property (strong) NSTimer* uploadsTimer;
	@property (strong) NSObject* selectedCollection;
	@property (copy) NSString* currentSearch;
	@property BOOL isFetchingUploads, isCheckingForNewUploads, needsUploadsRetry;
	@property NSInteger uploadsRequestID, refreshes;
	- (void) startUploadsTimer;
	- (NSTimeInterval) uploadsCheckInterval;
	- (void) didFinishUpload;
	- (void) invalidateUploadsTimer;
	- (void) checkForNewUploads:(NSTimer *)timer;
	- (void) updateAccessibilityTextForUploads:(NSArray *)uploads;
	- (void) refreshUploadsForCurrentFilter;
	- (NSArray *) uploadsFromResponse:(UUHttpResponse *)response;
	@end
	@implementation TestController
	#{methods}
	- (void) refreshUploadsForCurrentFilter { self.refreshes++; self.uploadsRequestID++; }
	- (NSArray *) uploadsFromResponse:(UUHttpResponse *)response { return response.uploads; }
	@end
	@interface TestInfoController : NSObject
	@property (copy) NSString* url;
	@property (copy) NSString* text;
	@property BOOL isAI, editing;
	@property NSInteger updates;
	- (void) updateInfoNotification:(NSNotification *)notification;
	- (BOOL) isEditing;
	- (void) hideEditing;
	- (void) setupWithURL:(NSString *)url text:(NSString *)text isAI:(BOOL)isAI;
	@end
	@implementation TestInfoController
	#{info_method}
	- (BOOL) isEditing { return self.editing; }
	- (void) hideEditing { self.editing = NO; }
	- (void) setupWithURL:(NSString *)url text:(NSString *)text isAI:(BOOL)isAI
	{
		self.url = url;
		self.text = text;
		self.isAI = isAI;
		self.updates++;
	}
	@end
	static RFUpload* Upload(NSString* url, NSString* alt, BOOL ai)
	{
		RFUpload* upload = [RFUpload new];
		upload.url = url;
		upload.alt = alt;
		upload.isAI = ai;
		return upload;
	}
	static void Complete(NSArray* uploads)
	{
		NSCAssert(pending_response != nil, @"There is an outstanding check");
		UUHttpResponse* response = [UUHttpResponse new];
		response.uploads = uploads;
		void (^handler)(UUHttpResponse*) = pending_response;
		pending_response = nil;
		handler(response);
	}
	int main(void)
	{
		@autoreleasepool {
			RFUpload* first = Upload(@"photo-a.jpg", @"", NO);
			RFUpload* second = Upload(@"photo-b.jpg", nil, NO);
			first.cachedImage = [NSObject new];
			NSObject* cached_image = first.cachedImage;
			TestController* controller = [TestController new];
			controller.allPosts = @[ first, second ];
			controller.collectionView = [TestCollection new];
			RFPhotoCell* cell = [RFPhotoCell new];
			controller.collectionView.cells = @{ @0: cell };
			TestInfoController* info = [TestInfoController new];
			info.url = first.url;
			[[NSNotificationCenter defaultCenter] addObserver:info selector:@selector(updateInfoNotification:) name:kUpdateInfoNotification object:nil];

			[controller startUploadsTimer];
			NSCAssert(controller.uploadsTimer.timeInterval == 10, @"Normal checks every ten seconds");
			NSTimer* old_timer = controller.uploadsTimer;
			[controller didFinishUpload];
			NSCAssert(!old_timer.valid && controller.uploadsTimer.timeInterval == 5, @"Upload completion starts five-second checks");
			controller.lastUploadFinishedAt = [NSDate dateWithTimeIntervalSinceNow:-59];
			NSCAssert([controller uploadsCheckInterval] == 5, @"Fast checks last a minute");
			[controller checkForNewUploads:controller.uploadsTimer];
			NSCAssert([last_args[@"limit"] integerValue] == 30 && [last_args[@"q"] isEqualToString:@"source"], @"Check the recent batch, not just one upload");
			[controller checkForNewUploads:controller.uploadsTimer];
			NSCAssert(requests == 1, @"Coalesce checks while a request is pending");
			Complete(@[ Upload(first.url, @"A mountain", YES), Upload(second.url, @"A lake", YES) ]);
			NSCAssert([first.alt isEqualToString:@"A mountain"] && [second.alt isEqualToString:@"A lake"], @"Update all matching photos, including offscreen ones");
			NSCAssert(first.isAI && cell.isAI && [cell.alt isEqualToString:first.alt], @"Update the live cell metadata");
			NSCAssert(controller.refreshes == 0 && first.cachedImage == cached_image, @"Do not reset selection or thumbnail cache for metadata changes");
			NSCAssert(info.updates == 1 && [info.text isEqualToString:first.alt], @"Refresh the matching open Info window only");

			[controller checkForNewUploads:controller.uploadsTimer];
			Complete(@[ Upload(first.url, first.alt, YES), Upload(second.url, second.alt, YES) ]);
			NSCAssert(info.updates == 1, @"Unchanged metadata causes no UI updates");
			info.editing = YES;
			[controller checkForNewUploads:controller.uploadsTimer];
			Complete(@[ Upload(first.url, @"Updated text", NO) ]);
			NSCAssert(info.editing && info.updates == 1 && [first.alt isEqualToString:@"Updated text"], @"Background updates must not interrupt description editing");
			info.editing = NO;
			[controller updateAccessibilityTextForUploads:@[ Upload(first.url, first.alt, YES) ]];
			NSCAssert(info.updates == 2 && info.isAI, @"Detect provenance changes even if the text stays the same");

			controller.lastUploadFinishedAt = [NSDate dateWithTimeIntervalSinceNow:-61];
			old_timer = controller.uploadsTimer;
			[controller checkForNewUploads:old_timer];
			NSCAssert(!old_timer.valid && controller.uploadsTimer.timeInterval == 10, @"Return to ten-second checks after a minute");
			Complete(@[ Upload(@"new-photo.jpg", @"", NO) ]);
			NSCAssert(controller.refreshes == 1, @"A new URL still refreshes the collection");
			[controller didFinishUpload];
			NSCAssert(controller.uploadsTimer.timeInterval == 5, @"Another completed upload restarts the fast-check window");

			for (NSNumber* condition in @[ @0, @1, @2, @3, @4 ]) {
				[controller checkForNewUploads:controller.uploadsTimer];
				switch (condition.integerValue) {
					case 0: controller.uploadsRequestID++; break;
					case 1: destination = @"site-b"; break;
					case 2: controller.currentSearch = @"search"; break;
					case 3: controller.selectedCollection = [NSObject new]; break;
					case 4: [controller invalidateUploadsTimer]; break;
				}
				Complete(@[ Upload(first.url, @"Stale result", YES) ]);
				NSCAssert([first.alt isEqualToString:@"Updated text"], @"Ignore responses after a refresh, context change, or leaving Uploads");
				destination = @"site-a";
				controller.currentSearch = nil;
				controller.selectedCollection = nil;
			}
			[controller didFinishUpload];
			NSCAssert(controller.uploadsTimer == nil, @"A hidden pane must not restart its timer after an upload finishes");
			[controller startUploadsTimer];
			[controller checkForNewUploads:controller.uploadsTimer];
			Complete(nil);
			[controller checkForNewUploads:controller.uploadsTimer];
			Complete(@[]);
			NSCAssert([first.alt isEqualToString:@"Updated text"] && controller.refreshes == 1, @"Failed/empty checks leave cached data intact");

			NSInteger request_count = requests;
			controller.currentSearch = @"search";
			[controller checkForNewUploads:controller.uploadsTimer];
			controller.currentSearch = nil;
			controller.selectedCollection = [NSObject new];
			[controller checkForNewUploads:controller.uploadsTimer];
			controller.selectedCollection = nil;
			controller.isFetchingUploads = YES;
			[controller checkForNewUploads:controller.uploadsTimer];
			NSCAssert(requests == request_count, @"Preserve existing search, collection, and active-fetch guards");
			[controller invalidateUploadsTimer];
			[[NSNotificationCenter defaultCenter] removeObserver:info];
			NSLog(@"Uploads background check tests passed.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-uploads-check-tests-') do |directory|
	path = File.join(directory, 'uploads.m')
	binary = File.join(directory, 'uploads')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-I', File.join(root, 'Source'), '-framework', 'Foundation', path, '-o', binary)
	abort 'Background check tests failed' unless system(binary)
end
