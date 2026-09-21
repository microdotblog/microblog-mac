# Run with: ruby Tests/upload_notification_routing_test.rb
# Exercise the production notification adapter and observer registration without
# loading nibs, accessing an account, or making any upload requests.
require 'tmpdir'

root = File.expand_path('..', __dir__)
uploads = File.read(File.join(root, 'Source/RFAllUploadsController.m'))
posts = File.read(File.join(root, 'Source/RFPostController.m'))
adapter = uploads[/^- \(void\) uploadFilesNotification:.*?^\}/m] or abort 'Upload adapter not found'
registration = posts.lines.find { |line| line.include?('addObserver:self selector:@selector(attachFilesNotification:)') } or abort 'Attachment registration not found'
picker = uploads[/^- \(IBAction\) promptForUpload:.*?^\}/m] or abort 'File picker not found'
abort 'File picker must call uploadFiles directly' unless picker.include?('[self uploadFiles:selected_paths]') && !picker.include?('postNotificationName:')

source = <<~OBJC
	#import <Foundation/Foundation.h>
	static NSString* const kUploadFilesNotification = @"UploadFiles";
	static NSString* const kUploadFilesPathsKey = @"paths";
	static NSString* const kAttachFilesNotification = @"AttachFiles";
	@interface TestView : NSObject
	@property (strong) NSObject* enclosingScrollView;
	@end
	@implementation TestView
	@end
	@interface TestController : NSObject
	@property (strong) TestView* collectionView;
	@property (strong) NSObject* textView;
	@property NSInteger uploads;
	@property NSInteger attachments;
	- (void) uploadFiles:(NSArray *)paths;
	- (void) uploadFilesNotification:(NSNotification *)notification;
	@end
	@implementation TestController
	- (instancetype) init
	{
		self = [super init];
		if (self) {
			self.collectionView = [TestView new];
			self.collectionView.enclosingScrollView = [NSObject new];
			self.textView = [NSObject new];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFilesNotification:) name:kUploadFilesNotification object:nil];
			#{registration.strip}
		}
		return self;
	}
	#{adapter}
	- (void) uploadFiles:(NSArray *)paths
	{
		NSCAssert(paths.count == 1, @"Paths forwarded intact");
		self.uploads++;
	}
	- (void) attachFilesNotification:(NSNotification *)notification
	{
		self.attachments++;
	}
	@end
	int main(void)
	{
		@autoreleasepool {
			NSArray* controllers = @[ [TestController new], [TestController new], [TestController new] ];
			NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
			for (TestController* owner in controllers) {
				for (id sender in @[ owner, owner.collectionView, owner.collectionView.enclosingScrollView ]) {
					[center postNotificationName:kUploadFilesNotification object:sender userInfo:@{ kUploadFilesPathsKey: @[ @"photo.jpg" ] }];
				}
				[center postNotificationName:kAttachFilesNotification object:owner.textView];
			}
			[center postNotificationName:kUploadFilesNotification object:nil];
			[center postNotificationName:kUploadFilesNotification object:[NSObject new]];
			[center postNotificationName:kAttachFilesNotification object:[NSObject new]];
			for (TestController* controller in controllers) {
				NSCAssert(controller.uploads == 3, @"Only the owner's three senders may upload");
				NSCAssert(controller.attachments == 1, @"Only the owner's editor may attach");
			}
			NSLog(@"Upload notification routing tests passed with three live controllers.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-routing-tests-') do |directory|
	path = File.join(directory, 'routing.m')
	binary = File.join(directory, 'routing')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Routing tests failed' unless system(binary)
end
