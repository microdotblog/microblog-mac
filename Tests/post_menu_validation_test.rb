# Run with: ruby Tests/post_menu_validation_test.rb
# Exercise production menu validation without opening a window or networking.
require 'tmpdir'

root = File.expand_path('..', __dir__)
posts = File.read(File.join(root, 'Source/RFPostController.m'))
validation = posts[/^- \(BOOL\) validateMenuItem:.*?^\}/m] or abort 'Missing post menu validation'

source = <<~OBJC
	#import <Foundation/Foundation.h>
	static NSInteger const NSControlStateValueOn = 1;
	static NSInteger const NSControlStateValueOff = 0;
	static BOOL snippets_blog = YES, external_blog = NO;
	@interface RFSettings : NSObject
	+ (BOOL) hasSnippetsBlog;
	+ (BOOL) prefersExternalBlog;
	@end
	@implementation RFSettings
	+ (BOOL) hasSnippetsBlog { return snippets_blog; }
	+ (BOOL) prefersExternalBlog { return external_blog; }
	@end
	@interface NSMenuItem : NSObject
	@property SEL action;
	@property NSInteger state;
	@end
	@implementation NSMenuItem
	@end
	@interface RFPost : NSObject
	@property BOOL isDraft;
	@end
	@implementation RFPost
	@end
	@interface TestController : NSObject
	@property BOOL isSending, isReply, page;
	@property BOOL isShowingTitle, isShowingCategories, isShowingCrosspostServices, isShowingSummary;
	@property (copy) NSString* text;
	@property (strong) NSArray* attachedPhotos;
	@property (strong) RFPost* editingPost;
	- (BOOL) isPage;
	- (NSString *) currentText;
	- (BOOL) validateMenuItem:(NSMenuItem *)item;
	@end
	@implementation TestController
	- (BOOL) isPage { return self.page; }
	- (NSString *) currentText { return self.text; }
	#{validation}
	@end
	static BOOL enabled(TestController* controller, NSString* action)
	{
		NSMenuItem* item = [NSMenuItem new];
		item.action = NSSelectorFromString(action);
		return [controller validateMenuItem:item];
	}
	static void expect_all(TestController* controller, BOOL expected)
	{
		for (NSString* action in @[@"sendPost:", @"save:", @"schedulePost:"]) {
			NSCAssert(enabled(controller, action) == expected, @"Unexpected validation for %@", action);
		}
	}
	int main(void)
	{
		@autoreleasepool {
			TestController* controller = [TestController new];
			expect_all(controller, NO);
			controller.text = @"";
			controller.attachedPhotos = @[];
			expect_all(controller, NO);
			NSCAssert(enabled(controller, @"toggleTitleField:"), @"Unrelated menu items remain available in an empty post");
			controller.text = @"A post";
			expect_all(controller, YES);
			controller.text = @"";
			controller.attachedPhotos = @[[NSObject new]];
			expect_all(controller, YES);
			controller.isSending = YES;
			expect_all(controller, NO);
			controller.text = @"A post";
			expect_all(controller, NO);
			NSCAssert(enabled(controller, @"toggleTitleField:"), @"Sending only affects publishing actions");
			controller.isSending = NO;
			controller.attachedPhotos = @[];
			expect_all(controller, YES);

			controller.page = YES;
			NSCAssert(enabled(controller, @"sendPost:") && !enabled(controller, @"save:") && !enabled(controller, @"schedulePost:"), @"Preserve Page restrictions");
			controller.page = NO;
			controller.isReply = YES;
			NSCAssert(enabled(controller, @"sendPost:") && !enabled(controller, @"save:") && !enabled(controller, @"schedulePost:"), @"Preserve Reply restrictions");
			controller.isReply = NO;
			snippets_blog = NO;
			NSCAssert(enabled(controller, @"sendPost:") && !enabled(controller, @"save:") && !enabled(controller, @"schedulePost:"), @"Preserve server capabilities");
			snippets_blog = YES;
			external_blog = YES;
			NSCAssert(enabled(controller, @"sendPost:") && !enabled(controller, @"save:") && !enabled(controller, @"schedulePost:"), @"Preserve external-blog restrictions");
			external_blog = NO;
			controller.editingPost = [RFPost new];
			NSCAssert(!enabled(controller, @"schedulePost:"), @"Cannot schedule an already-published post");
			controller.editingPost.isDraft = YES;
			expect_all(controller, YES);
			controller.text = @"";
			expect_all(controller, NO);
			NSLog(@"Post menu validation passed for empty, text-only, photo-only, sending, Pages, Replies, and drafts.");
		}
		return 0;
	}
OBJC

Dir.mktmpdir('microblog-post-menu-tests-') do |directory|
	path = File.join(directory, 'validation.m')
	binary = File.join(directory, 'validation')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Menu validation tests failed' unless system(binary)
end
