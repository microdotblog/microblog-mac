# Run with: ruby Tests/post_attachment_editing_test.rb
# Exercise the production save/reconciliation code with controlled responses.
# No account, window, image files, or network connections are used.
require 'tmpdir'

root = File.expand_path('..', __dir__)
posts = File.read(File.join(root, 'Source/RFPostController.m'))
windows = File.read(File.join(root, 'Source/RFPostWindowController.m'))
def method_source(source, name)
	source[/^- \([^\n]+\) #{Regexp.escape(name)}\b[^;\n]*\n\{.*?^\}/m] or abort "Missing #{name}"
end
names = %w[canAttachPhotos hasVideoURLs validatePhotoURLsForAttachment validateReadyToUploadPost hasPendingVideoTranscodes currentServerAutosavePayload serverAutosaveFingerprintForPayload currentServerAutosaveFingerprint currentStatus finishSavingDraftWithPhotoURLs attachmentHTMLFromSavedContent refreshSavedDraftMediaWithCompletion performManualActionAfterAutosave hideProgressHeader]
methods = names.map { |name| method_source(posts, name) }
declarations = methods.map { |body| body.lines.first.chomp + ';' }.join("\n")
native_upload = method_source(posts, 'uploadText')[/\t\tif \(\[self hasSnippetsBlog\].*?(?=\t\telse if \(\[self hasMicropubBlog\])/m] or abort 'Missing native upload branch'
attachment_guard = method_source(posts, 'attachPhotos').split("\tNSMutableArray* new_photos", 2).first
window_methods = %w[isNeedingSavePrompt draftDidUpdateNotification].map { |name| method_source(windows, name) }.join("\n")

source = <<~'OBJC'
	#import <Foundation/Foundation.h>
	#define RFDispatchMainAsync(block) block()
	static NSString* const kPostWindowDidCloseNotification = @"window-closed";
	static NSMutableArray* requests;
	static NSUInteger alerts;
	@interface NSAlert : NSObject
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler;
	@end
	@implementation NSAlert
	+ (void) rf_showOneButtonAlert:(NSString *)title message:(NSString *)message button:(NSString *)button completionHandler:(id)handler { alerts++; }
	@end
	@interface NSError (TestNetwork)
	- (NSString *) mb_networkMessageWithResponse:(id)response;
	@end
	@implementation NSError (TestNetwork)
	- (NSString *) mb_networkMessageWithResponse:(id)response { return @"Network error"; }
	@end
	@interface NSDate (TestDate)
	- (NSString *) uuRfc3339StringForUTCTimeZone;
	@end
	@implementation NSDate (TestDate)
	- (NSString *) uuRfc3339StringForUTCTimeZone { return @"2026-12-01T12:00:00Z"; }
	@end
	@interface RFPhoto : NSObject
	@property (copy) NSString* publishedURL;
	@property (copy) NSString* altText;
	@property (strong) id thumbnailImage;
	@property BOOL isUndeletable, isVideo, isUploadingForAltText;
	@property NSUInteger temporaryRemovals;
	- (void) removeTemporaryVideo;
	@end
	@implementation RFPhoto
	- (void) removeTemporaryVideo { self.temporaryRemovals++; }
	@end
	@interface RFPost : NSObject
	@property (copy) NSString* url;
	@property (copy) NSString* text;
	@property BOOL isDraft;
	@end
	@implementation RFPost
	@end
	@interface TestWindow : NSObject
	@property (getter=isDocumentEdited) BOOL documentEdited;
	@end
	@implementation TestWindow
	@end
	@interface TestView : NSObject
	@property (strong) TestWindow* window;
	@end
	@implementation TestView
	@end
	@interface TestTextView : NSObject
	@property (strong) NSMutableString* textStorage;
	@property (copy) NSString* string;
	@property NSRange selectedRange;
	@end
	@implementation TestTextView
	- (NSString *) string { return self.textStorage; }
	- (void) setString:(NSString *)string
	{
		if (self.textStorage) {
			[self.textStorage setString:string];
		}
		else {
			self.textStorage = [string mutableCopy];
		}
	}
	@end
	@interface TestCollection : NSObject
	@property NSUInteger reloads;
	- (void) reloadData;
	@end
	@implementation TestCollection
	- (void) reloadData { self.reloads++; }
	@end
	@interface TestConstraint : NSObject
	@property double constant;
	- (instancetype) animator;
	@end
	@implementation TestConstraint
	- (instancetype) animator { return self; }
	@end
	@interface UUHttpResponse : NSObject
	@property (strong) id parsedResponse;
	@property (strong) NSError* httpError;
	@property (strong) NSHTTPURLResponse* httpResponse;
	@end
	@implementation UUHttpResponse
	@end
	@interface TestRequest : NSObject
	@property (copy) NSString* method;
	@property (strong) NSDictionary* args;
	@property (copy) void (^completion)(UUHttpResponse*);
	@end
	@implementation TestRequest
	@end
	@interface RFClient : NSObject
	- (instancetype) initWithPath:(NSString *)path;
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion;
	- (void) postWithObject:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion;
	- (void) postWithParams:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion;
	@end
	@implementation RFClient
	- (instancetype) initWithPath:(NSString *)path
	{
		NSCAssert([path isEqualToString:@"/micropub"], @"Use Micropub");
		return [super init];
	}
	- (void) record:(NSString *)method arguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion
	{
		TestRequest* request = [TestRequest new];
		request.method = method;
		request.args = args;
		request.completion = completion;
		[requests addObject:request];
	}
	- (void) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion { [self record:@"GET" arguments:args completion:completion]; }
	- (void) postWithObject:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion { [self record:@"POST" arguments:args completion:completion]; }
	- (void) postWithParams:(NSDictionary *)args completion:(void (^)(UUHttpResponse*))completion { [self record:@"POST" arguments:args completion:completion]; }
	@end
	@interface TestController : NSObject
	@property BOOL isReply, page, snippets, external, isSending, isDraft, hasClosed, isEditingExistingPost;
	@property BOOL serverAutosavePausedForManualAction, serverAutosaveRequestInFlight;
	@property NSInteger pendingAttachmentSlots;
	@property NSUInteger updates, closes, loadingStarts;
	@property (strong) TestView* view;
	@property (strong) TestTextView* textView;
	@property (strong) TestTextView* summaryTextView;
	@property (strong) TestCollection* photosCollectionView;
	@property (strong) TestConstraint* photosHeightConstraint;
	@property (strong) NSUndoManager* textUndoManager;
	@property (strong) RFPost* editingPost;
	@property (strong) NSArray* attachedPhotos;
	@property (strong) NSArray* libraryImportQueue;
	@property (strong) NSArray* selectedCategories;
	@property (strong) NSArray* selectedCrosspostUIDs;
	@property (copy) NSArray* pendingSavedMediaURLs;
	@property (copy) NSDictionary* pendingSavedMediaPayload;
	@property (copy) NSString* boundDestinationUID;
	@property (copy) NSString* destinationUID;
	@property (copy) NSString* title;
	@property (copy) NSString* initialText;
	@property (copy) NSString* channel;
	@property (copy) NSString* savedEditorFingerprint;
	@property (copy) NSString* serverAutosaveSavedFingerprint;
	@property (copy) NSString* serverAutosaveSiteID;
	@property (strong) NSDate* postedAt;
	@property (strong) NSTimer* serverAutosaveTimer;
	@property (copy) void (^pendingManualAction)(void);
	__DECLARATIONS__
	- (void) uploadNativeText:(NSString *)text;
	- (void) attachPhotos:(NSArray *)photoURLs;
	- (BOOL) isPage;
	- (NSString *) currentText;
	- (NSString *) currentTitle;
	- (NSString *) currentDestinationUID;
	- (NSString *) currentServerAutosaveSiteID;
	@end
	@implementation TestController
	- (BOOL) isPage { return self.page; }
	- (BOOL) hasSnippetsBlog { return self.snippets; }
	- (BOOL) prefersExternalBlog { return self.external; }
	- (NSString *) currentText { return self.textView.string; }
	- (NSString *) currentTitle { return self.title; }
	- (NSString *) currentDestinationUID { return self.boundDestinationUID ?: self.destinationUID ?: @"https://example.micro.blog/"; }
	- (NSString *) currentServerAutosaveSiteID { return @"example.micro.blog"; }
	- (void) showProgressHeader:(NSString *)status {}
	- (void) setupBlogName {}
	- (void) stopProgressAnimation {}
	- (void) resumeServerAutosaveAfterManualAction { self.serverAutosavePausedForManualAction = NO; }
	- (void) updateLibraryAttachmentSpacing {}
	- (void) updateRemainingChars {}
	- (void) updateTitleHeader {}
	- (void) updateGenerateEnabled {}
	- (void) sendUpdatedDraftNotification { self.updates++; }
	- (void) closeWithoutSaving { self.closes++; }
	__METHODS__
	- (void) uploadNativeText:(NSString *)text
	{
		NSString* summary = self.summaryTextView.string;
		__NATIVE_UPLOAD__
	}
	__ATTACHMENT_GUARD__
		self.loadingStarts++;
	}
	@end
	@interface TestWindowController : NSObject
	@property (strong) TestController* postController;
	@property (strong) TestWindow* window;
	@property (strong) NSTimer* previewTimer;
	@property BOOL isSavingAndClosing;
	@property NSUInteger closes;
	- (BOOL) isNeedingSavePrompt;
	- (void) draftDidUpdateNotification:(NSNotification *)notification;
	@end
	@implementation TestWindowController
	- (void) close { self.closes++; }
	__WINDOW_METHODS__
	@end
	static RFPhoto* photo(NSString* url)
	{
		RFPhoto* result = [RFPhoto new];
		result.publishedURL = url;
		result.altText = @"Photo > detail";
		return result;
	}
	static TestController* controller(NSString* text)
	{
		TestController* result = [TestController new];
		result.snippets = YES;
		result.isDraft = YES;
		result.isEditingExistingPost = YES;
		result.title = @"A title";
		result.channel = @"default";
		result.view = [TestView new];
		result.view.window = [TestWindow new];
		result.textView = [TestTextView new];
		result.textView.string = text;
		result.summaryTextView = [TestTextView new];
		result.summaryTextView.string = @"";
		result.photosCollectionView = [TestCollection new];
		result.photosHeightConstraint = [TestConstraint new];
		result.textUndoManager = [NSUndoManager new];
		result.selectedCategories = @[@"photos"];
		result.selectedCrosspostUIDs = @[];
		result.attachedPhotos = @[];
		result.editingPost = [RFPost new];
		result.editingPost.url = @"https://example.micro.blog/2026/post.html";
		result.editingPost.isDraft = YES;
		return result;
	}
	static UUHttpResponse* response(id parsed)
	{
		UUHttpResponse* result = [UUHttpResponse new];
		result.parsedResponse = parsed;
		result.httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.micro.blog/"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
		return result;
	}
	static void respond_content(NSString* content)
	{
		TestRequest* request = requests.lastObject;
		NSCAssert([request.method isEqualToString:@"GET"] && [request.args[@"q"] isEqualToString:@"source"], @"Refresh source before continuing");
		request.completion(response(@{@"properties": @{@"content": @[content]}}));
	}
	static void save_with_photo(TestController* post, NSString* url)
	{
		post.attachedPhotos = @[photo(url)];
		post.isSending = YES;
		[post finishSavingDraftWithPhotoURLs:@[url] submittedPayload:[post currentServerAutosavePayload]];
	}
	int main(void)
	{
		@autoreleasepool {
			requests = [NSMutableArray array];
			NSString* url = @"https://example.micro.blog/uploads/photo.jpg";
			NSString* html = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"Photo > detail\">", url];
			NSString* url2 = @"https://example.micro.blog/uploads/photo2.jpg";
			NSString* html2 = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"Second\">", url2];
			TestController* post = controller(@"A post");
			NSCAssert([post canAttachPhotos], @"Existing drafts support the photo picker");
			post.editingPost.isDraft = NO;
			NSCAssert([post canAttachPhotos], @"Published and scheduled posts support the photo picker");
			post.isReply = YES;
			NSCAssert(![post canAttachPhotos], @"Replies do not show the picker");
			post.isReply = NO;
			post.page = YES;
			NSCAssert(![post canAttachPhotos], @"Pages do not show the picker");
			post.page = NO;
			post.external = YES;
			NSCAssert(![post canAttachPhotos], @"External edits retain existing restrictions");
			post.external = NO;
			post.snippets = NO;
			NSCAssert(![post canAttachPhotos], @"Edited posts require the native service");
			post.editingPost = nil;
			NSCAssert([post canAttachPhotos], @"Existing new-post picker support remains");

			post = controller(@"Before https://example.com and @manton");
			NSString* original_text = [[post currentText] copy];
			NSRange mention_range = [original_text rangeOfString:@"@manton"];
			post.textView.selectedRange = mention_range;
			post.textUndoManager.groupsByEvent = NO;
			[post.textUndoManager beginUndoGrouping];
			[post.textUndoManager registerUndoWithTarget:post.textView.textStorage handler:^(NSMutableString* text) {
				[text replaceCharactersInRange:mention_range withString:@""];
			}];
			[post.textUndoManager endUndoGrouping];
			save_with_photo(post, url);
			NSCAssert([post.attachedPhotos.firstObject isUndeletable], @"Committed uploads cannot be deleted by attachment Remove");
			NSString* normalized = [@"Before [example.com](https://example.com) and [@manton](https://micro.blog/manton)\n\n" stringByAppendingString:html];
			respond_content(normalized);
			NSString* local_saved_text = [[original_text stringByAppendingString:@"\n\n"] stringByAppendingString:html];
			NSCAssert([[post currentText] isEqualToString:local_saved_text] && post.attachedPhotos.count == 0 && post.pendingSavedMediaURLs == nil, @"Server normalization does not replace the local prefix while saved media is reconciled exactly once");
			NSCAssert([post.editingPost.text isEqualToString:normalized] && [post.initialText isEqualToString:local_saved_text], @"Retain normalized server source separately from the saved editor baseline");
			NSCAssert(!post.view.window.documentEdited && post.updates == 1 && post.photosHeightConstraint.constant == 0, @"Successful reconciliation is clean and completes the save");
			NSCAssert(NSEqualRanges(post.textView.selectedRange, mention_range) && post.textUndoManager.canUndo, @"Preserve selection and previously registered undo operations");
			[post.textUndoManager undo];
			NSCAssert([[post currentText] isEqualToString:[@"Before https://example.com and \n\n" stringByAppendingString:html]] && !post.textUndoManager.canUndo, @"Old undo ranges still target the same text and media insertion adds no undo entry");

			post = controller(@"Draft submitted");
			post.attachedPhotos = @[photo(url)];
			[post uploadNativeText:[post currentText]];
			TestRequest* draft_update = requests.lastObject;
			NSCAssert([draft_update.args[@"replace"][@"post-status"] isEqualToString:@"draft"], @"Saving an existing draft uses the update endpoint and keeps draft status");
			post.title = @"Changed during update";
			draft_update.completion(response(nil));
			TestRequest* draft_refresh = requests.lastObject;
			NSCAssert([draft_refresh.method isEqualToString:@"GET"] && [draft_refresh.args[@"url"] isEqualToString:post.editingPost.url] && [draft_refresh.args[@"mp-destination"] isEqualToString:[post currentDestinationUID]], @"A successful draft update fetches source for the same post and destination");
			respond_content([@"Draft submitted\n\n" stringByAppendingString:html]);
			NSCAssert(post.view.window.documentEdited && [post.title isEqualToString:@"Changed during update"], @"The saved baseline uses the payload captured before the update request");

			post = controller(@"Submitted");
			save_with_photo(post, url);
			post.textView.string = @"Newer edits";
			respond_content([@"Submitted\n\n" stringByAppendingString:html]);
			NSCAssert([[post currentText] isEqualToString:[@"Newer edits\n\n" stringByAppendingString:html]], @"Keep edits made while the source request is in flight");
			NSCAssert(post.view.window.documentEdited && post.attachedPhotos.count == 0, @"Concurrent edits remain unsaved");
			post = controller(@"Submitted");
			save_with_photo(post, url);
			post.title = @"Only title changed";
			respond_content([@"Submitted\n\n" stringByAppendingString:html]);
			NSCAssert(post.view.window.documentEdited, @"Title-only edits during refresh remain dirty");

			NSString* existing = [NSString stringWithFormat:@"Existing %@ and %@", html, html2];
			post = controller(existing);
			post.attachedPhotos = @[photo(url), photo(url2)];
			[post finishSavingDraftWithPhotoURLs:@[url, url2] submittedPayload:[post currentServerAutosavePayload]];
			NSString* combined = [NSString stringWithFormat:@"%@\n\n%@%@", existing, html, html2];
			respond_content(combined);
			NSCAssert([[post currentText] isEqualToString:combined] && post.attachedPhotos.count == 0, @"Existing image tags remain and only the trailing ordered photo group is reconciled");
			NSCAssert(([[post attachmentHTMLFromSavedContent:combined photoURLs:@[url, url2] videoURLs:@[]] isEqualToString:[html stringByAppendingString:html2]]), @"Extract just the appended block");
			NSCAssert(([post attachmentHTMLFromSavedContent:combined photoURLs:@[url2, url] videoURLs:@[]] == nil), @"Wrong image order does not clear attachments");

			for (id invalid in @[@{ @"properties": @{ @"content": @[@"Missing photos"] } }, @{ @"properties": @{ @"content": @[html2] } }, @{ @"properties": @{ @"content": @42 } }, [NSNull null]]) {
				post = controller(@"Submitted");
				save_with_photo(post, url);
				[requests.lastObject completion](response(invalid));
				NSCAssert(post.pendingSavedMediaURLs.count == 1 && post.attachedPhotos.count == 1 && post.view.window.documentEdited && post.updates == 0 && !post.isSending, @"Bad source responses retain recoverable state and never announce save completion");
			}
			post = controller(@"Submitted");
			save_with_photo(post, url);
			UUHttpResponse* failed = response(nil);
			failed.httpError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
			[requests.lastObject completion](failed);
			__block NSUInteger new_updates = 0;
			post.isSending = YES;
			[post performManualActionAfterAutosave:^{
				new_updates++;
				NSCAssert(post.pendingSavedMediaURLs == nil && post.attachedPhotos.count == 0, @"Retry must reconcile before constructing another update");
				[post uploadNativeText:[post currentText]];
			}];
			NSCAssert(new_updates == 0 && post.pendingSavedMediaURLs.count == 1, @"Source retry does not resend photos");
			respond_content([@"Submitted\n\n" stringByAppendingString:html]);
			TestRequest* retry = requests.lastObject;
			NSCAssert(new_updates == 1 && [retry.method isEqualToString:@"POST"] && retry.args[@"replace"][@"photo"] == nil, @"Next update contains reconciled HTML without duplicate photo parameters");

			post = controller(existing);
			post.attachedPhotos = @[photo(url)];
			post.isDraft = NO;
			post.editingPost.isDraft = NO;
			[post uploadNativeText:existing];
			TestRequest* update = requests.lastObject;
			NSDictionary* replace = update.args[@"replace"];
			NSCAssert([update.args[@"action"] isEqualToString:@"update"] && [replace[@"content"] isEqualToString:existing], @"Update existing content without parsing or replacing its img tags");
			NSCAssert(([replace[@"photo"] isEqual:@[@{@"value":url, @"alt":@"Photo &gt; detail"}]]), @"Send only new photo URLs and safely escaped descriptions");
			NSCAssert(replace[@"published"] == nil && [replace[@"post-status"] isEqualToString:@"published"], @"An ordinary Update preserves the existing published or scheduled date");
			update.completion(response(nil));
			NSCAssert(post.closes == 1, @"An empty HTTP 200 response completes a published-post update");
			post.postedAt = [NSDate date];
			[post uploadNativeText:existing];
			NSCAssert([requests.lastObject args][@"replace"][@"published"] != nil, @"Explicit scheduling still sends its selected date");

			post = controller(@"Quoted description");
			RFPhoto* quoted = photo(url);
			quoted.altText = @"A \"quoted\" <thing> & detail";
			post.attachedPhotos = @[quoted];
			[post uploadNativeText:[post currentText]];
			NSString* escaped_alt = [requests.lastObject args][@"replace"][@"photo"][0][@"alt"];
			NSCAssert([escaped_alt isEqualToString:@"A &quot;quoted&quot; &lt;thing&gt; &amp; detail"], @"Escape special characters exactly once for the raw-HTML update API");

			NSString* video_url = @"https://example.micro.blog/uploads/clip.mp4";
			NSString* video_html = [NSString stringWithFormat:@"<video controls=\"controls\" playsinline=\"playsinline\" preload=\"none\" width=\"640\" height=\"480\" poster=\"https://example.micro.blog/poster.jpg\" src=\"%@\"></video>", video_url];
			for (NSNumber* mixed in @[@YES, @NO]) {
				post = controller(@"New draft");
				post.editingPost = nil;
				post.isEditingExistingPost = NO;
				RFPhoto* video = photo(video_url);
				video.isVideo = YES;
				video.thumbnailImage = [NSObject new];
				post.attachedPhotos = mixed.boolValue ? @[quoted, video] : @[video];
				[post uploadNativeText:[post currentText]];
				TestRequest* create = requests.lastObject;
				NSCAssert(([create.args[@"video[]"] isEqual:@[video_url]]), @"New composer still uploads videos");
				if (mixed.boolValue) {
					NSCAssert([create.args[@"mp-photo-alt[]"][0] isEqualToString:quoted.altText], @"Create API receives raw alt text to avoid double escaping");
				}
				// The user changes destinations while the create request is in flight.
				post.destinationUID = @"https://another.micro.blog/";
				create.completion(response(@{@"url": @"https://example.micro.blog/2026/new.html"}));
				NSCAssert([post.boundDestinationUID isEqualToString:@"https://example.micro.blog/"] && [[requests.lastObject args][@"mp-destination"] isEqualToString:post.boundDestinationUID], @"Refresh remains bound to the destination that accepted the draft");
				NSCAssert([post.pendingSavedMediaPayload[@"photo_urls"] isKindOfClass:[NSArray class]] && [post.pendingSavedMediaPayload[@"video_urls"] isKindOfClass:[NSArray class]], @"Private snapshot retains separate photo and video arrays");
				NSCAssert(post.pendingSavedMediaURLs.count == (mixed.boolValue ? 2 : 1) && video.isUndeletable, @"Protect all committed media during source refresh");
				NSString* quoted_html = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"A &quot;quoted&quot; &lt;thing&gt; &amp; detail\">", url];
				NSString* attachment_html = mixed.boolValue ? [[quoted_html stringByAppendingString:@"\n\n"] stringByAppendingString:video_html] : video_html;
				NSString* saved_content = [@"New draft\n\n" stringByAppendingString:attachment_html];
				respond_content(saved_content);
				NSCAssert([[post currentText] isEqualToString:saved_content] && post.attachedPhotos.count == 0 && post.pendingSavedMediaURLs == nil && !post.view.window.documentEdited, @"Mixed and video-only drafts reconcile into editor HTML");
				NSCAssert(video.temporaryRemovals == 1, @"Retire the local video file after reconciliation");
				[post uploadNativeText:[post currentText]];
				NSDictionary* subsequent = [requests.lastObject args][@"replace"];
				NSCAssert(subsequent[@"photo"] == nil && subsequent[@"video"] == nil && [subsequent[@"content"] isEqualToString:saved_content], @"Subsequent save retains HTML and does not append media twice");
			}
			post = controller(@"Composer autosaved while importing video");
			post.isEditingExistingPost = NO;
			NSCAssert(([post validatePhotoURLsForAttachment:@[[NSURL fileURLWithPath:@"/tmp/clip.MOV"]]]), @"Autosaving a new composer does not remove its video attachment capability");
			RFPhoto* existing_video = photo(video_url);
			existing_video.isVideo = YES;
			post.attachedPhotos = @[existing_video];
			[post uploadNativeText:[post currentText]];
			NSCAssert(([[requests.lastObject args][@"replace"][@"video"] isEqual:@[video_url]]), @"A composer converted to an existing draft by autosave retains its video in the update payload");

			post = controller(@"");
			post.attachedPhotos = @[photo(url)];
			post.view.window.documentEdited = YES;
			TestWindowController* window = [TestWindowController new];
			window.postController = post;
			window.window = post.view.window;
			NSCAssert([window isNeedingSavePrompt], @"Photo-only edits prompt before closing");
			window.isSavingAndClosing = YES;
			[window draftDidUpdateNotification:nil];
			NSCAssert(window.closes == 0 && !window.isSavingAndClosing, @"Do not close over newer edits, and reset close intent");
			post.view.window.documentEdited = NO;
			window.isSavingAndClosing = YES;
			[window draftDidUpdateNotification:nil];
			NSCAssert(window.closes == 0, @"Remaining attachments prevent closing even if edited state was cleared");
			post.attachedPhotos = @[];
			window.isSavingAndClosing = YES;
			[window draftDidUpdateNotification:nil];
			NSCAssert(window.closes == 1, @"A fully saved draft closes normally");

			post = controller(@"Edited");
			NSUInteger alerts_before = alerts;
			[post attachPhotos:@[[NSURL fileURLWithPath:@"/tmp/clip.MOV"]]];
			NSCAssert(alerts == alerts_before + 1 && post.loadingStarts == 0, @"Reject videos before any transcode or upload for edited posts");
			post.isSending = YES;
			[post attachPhotos:@[[NSURL fileURLWithPath:@"/tmp/photo.jpg"]]];
			NSCAssert(post.loadingStarts == 0, @"Do not mutate attachments during an upload");
			post.isSending = NO;
			post.pendingAttachmentSlots = 1;
			NSCAssert(![post validateReadyToUploadPost], @"Wait for delayed file imports before sending");
			post.pendingAttachmentSlots = 0;
			NSCAssert([post validateReadyToUploadPost], @"A ready photo post may save");
			NSLog(@"Post attachment editing tests passed: eligibility, payload, normalization, concurrent edits, failed refresh/retry, closing, and video/import guards.");
		}
		return 0;
	}
OBJC
source = source.sub('__DECLARATIONS__') { declarations }.sub('__METHODS__') { methods.join("\n") }
source = source.sub('__NATIVE_UPLOAD__') { native_upload }.sub('__ATTACHMENT_GUARD__') { attachment_guard }.sub('__WINDOW_METHODS__') { window_methods }

Dir.mktmpdir('microblog-attachment-tests-') do |directory|
	path = File.join(directory, 'attachments.m')
	binary = File.join(directory, 'attachments')
	File.write(path, source)
	abort 'Compilation failed' unless system('xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation', path, '-o', binary)
	abort 'Attachment editing tests failed' unless system(binary)
end
