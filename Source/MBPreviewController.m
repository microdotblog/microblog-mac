//
//  MBPreviewController.m
//  Micro.blog
//
//  Created by Manton Reece on 1/8/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBPreviewController.h"

#import "RFPhoto.h"
#import "RFConstants.h"
#import "MMMarkdown.h"

// static storage for class-wide preview data
static NSString* gCurrentPreviewTitle = nil;
static NSString* gCurrentPreviewMarkdown = nil;
static NSArray* gCurrentPreviewPhotos = nil; // RFPhoto

@implementation MBPreviewController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Preview"];
	if (self) {
		self.cachedPhotoPaths = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupWindow];
	[self setupWebView];
	[self setupNotifications];
	[self setupInitialRender];
}

- (void) setupWindow
{
	[self.window setBackgroundColor:[NSColor colorNamed:@"color_preview_background"]];
}

- (void) setupWebView
{
	self.webview.alphaValue = 0.0;
	self.webview.navigationDelegate = self;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorWindowTextDidChangeNotification:) name:kEditorWindowTextDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillQuitNotification:) name:NSApplicationWillTerminateNotification object:nil];
}

- (void) setupInitialRender
{
	if (gCurrentPreviewTitle && gCurrentPreviewMarkdown && gCurrentPreviewPhotos) {
		[self renderPreviewTitle:gCurrentPreviewTitle markdown:gCurrentPreviewMarkdown photos:gCurrentPreviewPhotos];
	}
}

+ (void) setCurrentPreviewTitle:(NSString *)title markdown:(NSString *)markdown photos:(NSArray *)photos
{
	gCurrentPreviewTitle = [title copy];
	gCurrentPreviewMarkdown = [markdown copy];
	gCurrentPreviewPhotos = [photos copy];
}

- (void) cleanupTempFiles
{
	NSString* temp_folder = NSTemporaryDirectory();
	for (NSString* path in self.cachedPhotoPaths) {
		// sanity check we're in the temp folder, then delete
		NSString* full_path = [self.cachedPhotoPaths objectForKey:path];
		if ([full_path hasPrefix:temp_folder]) {
			NSError* error = nil;
			[[NSFileManager defaultManager] removeItemAtPath:full_path error:&error];
		}
	}
}

- (void) editorWindowTextDidChangeNotification:(NSNotification *)notification
{
	if ([self.window isVisible]) {
		NSString* title = [notification.userInfo objectForKey:kEditorWindowTextTitleKey];
		NSString* markdown = [notification.userInfo objectForKey:kEditorWindowTextMarkdownKey];
		NSArray* photos = [notification.userInfo objectForKey:kEditorWindowTextPhotosKey];

		[self renderPreviewTitle:title markdown:markdown photos:photos];
	}
}

- (void) appWillQuitNotification:(NSNotification *)notification
{
	[self cleanupTempFiles];
}

- (void) renderPreviewTitle:(NSString *)title markdown:(NSString *)markdown photos:(NSArray *)photos
{
	NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Preview" ofType:@"html"];
	NSString* template_html = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];
	
	NSURL* base_url = nil;;
	NSMutableString* photos_html = [[NSMutableString alloc] init];
	for (RFPhoto* photo in photos) {
		if (photo.fileURL) {
			[photos_html appendFormat:@"<img src=\"%@\">", photo.fileURL];
			base_url = [NSURL fileURLWithPath:[photo.fileURL.path stringByDeletingLastPathComponent] isDirectory:YES];
		}
		else {
			// to avoid re-saving the file, we'll cache a reference to the path
			NSValue* pointer_key = [NSValue valueWithNonretainedObject:photo];
			NSString* temp_path = [self.cachedPhotoPaths objectForKey:pointer_key];
			if (temp_path == nil) {
				temp_path = [self saveTemporaryPhoto:photo];
				[self.cachedPhotoPaths setObject:temp_path forKey:pointer_key];
			}
			[photos_html appendFormat:@"<img src=\"%@\">", temp_path];
			base_url = [NSURL fileURLWithPath:[temp_path stringByDeletingLastPathComponent] isDirectory:YES];
		}
	}
	
	NSError* error = nil;
	NSString* content_html = [MMMarkdown HTMLStringWithMarkdown:markdown extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
	if (error == nil) {
		NSString* html = template_html;
		html = [html stringByReplacingOccurrencesOfString:@"[TITLE]" withString:title];
		html = [html stringByReplacingOccurrencesOfString:@"[CONTENT]" withString:content_html];
		html = [html stringByReplacingOccurrencesOfString:@"[PHOTOS]" withString:photos_html];

		if (![html isEqualToString:self.html]) {
			self.html = html;
			[self.webview loadHTMLString:html baseURL:base_url];
		}
	}
}

- (NSString *) saveTemporaryPhoto:(RFPhoto *)photo
{
	// write image to temp file
	NSString* filename = [NSString stringWithFormat:@"Preview-%@.jpg", [[NSUUID UUID] UUIDString]];
	NSString* temp_folder = NSTemporaryDirectory();
	NSString* path = [temp_folder stringByAppendingPathComponent:filename];
	NSBitmapImageRep* img_rep = [[NSBitmapImageRep alloc] initWithData:[photo.thumbnailImage TIFFRepresentation]];
	NSData* d = [img_rep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{}];
	[d writeToFile:path atomically:YES];

	return path;
}

- (void) webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
	if (self.webview.alphaValue == 0.0) {
		self.webview.animator.alphaValue = 1.0;
	}
}

- (void) webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
		decisionHandler(WKNavigationActionPolicyCancel);
		[[NSWorkspace sharedWorkspace] openURL:navigationAction.request.URL];
	}
	else {
		decisionHandler(WKNavigationActionPolicyAllow);
	}
}

@end
