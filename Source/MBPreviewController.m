//
//  MBPreviewController.m
//  Micro.blog
//
//  Created by Manton Reece on 1/8/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBPreviewController.h"

#import "RFPhoto.h"
#import "RFSettings.h"
#import "RFConstants.h"
#import "MMMarkdown.h"
#import "HTMLParser.h"
#import "HTMLNode+Mutating.h"
#import <dispatch/dispatch.h>
#import <os/availability.h>

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
	
	[self fixPreferences];
	
	[self setupWindow];
	[self setupWebView];
	[self setupNotifications];
	[self setupUsingTheme];
	[self setupInitialRender];
}

- (void) fixPreferences
{
	// if no destination yet, set an initial value based on default site
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if ((destination_uid == nil) || ([destination_uid length] == 0)) {
		// usually this is custom domain, but okay to use subdomain here
		NSString* hostname = [RFSettings stringForKey:kAccountDefaultSite];
		destination_uid = [NSString stringWithFormat:@"https://%@/", hostname];
		[RFSettings setString:destination_uid forKey:kCurrentDestinationUID];
		[RFSettings setString:hostname forKey:kCurrentDestinationName];
	}
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
}

- (void) setupUsingTheme
{
	if ([RFSettings boolForKey:kIsUsingBlogThemePreview]) {
		[self.useThemeCheckbox setState:NSControlStateValueOn];
	}
}

- (void) setupInitialRender
{
	if ([RFSettings boolForKey:kIsUsingBlogThemePreview]) {
		// first clear template
		NSString* template_path = [self currentTemplatePath];
		[self removeTemplate:template_path];

		// re-download
		[self downloadTheme];
	}
	else {
		[self renderPreview];
	}
}

- (IBAction) useThemeChanged:(NSButton *)sender
{
	if (sender.state == NSControlStateValueOn) {
		[RFSettings setBool:YES forKey:kIsUsingBlogThemePreview];
		[self downloadTheme];
	}
	else {
		[RFSettings setBool:NO forKey:kIsUsingBlogThemePreview];
		[self clearTheme];
	}
}


#pragma mark -

- (void) downloadTheme
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	NSURL* blog_url = [NSURL URLWithString:destination_uid];
	
	NSString* template_path = [self currentTemplatePath];
	NSFileManager* fm = [NSFileManager defaultManager];
	
	// download theme if template doesn't exist yet
	if (![fm fileExistsAtPath:template_path]) {
		[self.progressSpinner startAnimation:nil];
		[self downloadHomePage:blog_url completion:^(NSString *updatedHTML, NSURL *baseURL) {
			[self.progressSpinner stopAnimation:nil];
			[self renderPreview];
		}];
	}
	else {
		[self renderPreview];
	}
}

- (void) clearTheme
{
	[RFSettings setBool:NO forKey:kIsUsingBlogThemePreview];
	[self renderPreview];

	// reset if checkbox title changed
	self.warningField.stringValue = @"";

	// remove the template too
	NSString* template_path = [self currentTemplatePath];
	[self removeTemplate:template_path];
}

- (void) removeTemplate:(NSString *)path
{
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	if ([fm fileExistsAtPath:path isDirectory:&is_dir]) {
		if (!is_dir) {
			[fm removeItemAtPath:path error:NULL];
		}
	}
}

- (void) showWarning:(NSString *)text
{
	self.warningField.hidden = NO;
	self.warningField.attributedStringValue = [self makeString:text withIcon:@"exclamationmark.triangle"];
}

- (nullable NSString *) permalinkInNode:(HTMLNode *)node requiringPublishedDate:(BOOL)requiringPublishedDate
{
	// find the first post permalink, optionally requiring a published date to avoid unrelated u-url links
	NSArray* a_tags = [node findChildTags:@"a"];
	for (HTMLNode* link_node in a_tags) {
		NSString* class_attr = [link_node getAttributeNamed:@"class"];
		if (class_attr && ([class_attr rangeOfString:@"u-url"].location != NSNotFound)) {
			if (requiringPublishedDate) {
				HTMLNode* date_node = [link_node findChildWithAttribute:@"class" matchingName:@"dt-published" allowPartial:YES];
				if (date_node == nil) {
					continue;
				}
			}

			NSString* permalink = [link_node getAttributeNamed:@"href"];
			if (permalink.length > 0) {
				return permalink;
			}
		}
	}

	return nil;
}

- (nullable HTMLNode *) articleWithPermalinkInNode:(HTMLNode *)node
{
	NSArray* article_tags = [node findChildTags:@"article"];
	for (HTMLNode* article_node in article_tags) {
		if ([self permalinkInNode:article_node requiringPublishedDate:YES]) {
			return article_node;
		}
	}

	return nil;
}

- (void) downloadHomePage:(NSURL *)blogURL completion:(void (^)(NSString* updatedHTML, NSURL* baseURL))completion
{
	// create request to ignore cache and always fetch latest page
	NSURLRequest* request = [NSURLRequest requestWithURL:blogURL
											 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
										 timeoutInterval:60.0];
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request
																completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
		if (error) {
			NSLog(@"Error downloading %@: %@", blogURL, error);
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showWarning:@"Error downloading blog template"];
				completion(nil, nil);
			});
			return;
		}
		
		NSString* htmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSError* parseError = nil;
		HTMLParser* parser1 = [[HTMLParser alloc] initWithString:htmlString error:&parseError];
		HTMLNode* root1 = [parser1 body];
		HTMLNode* entry1 = [root1 findChildWithAttribute:@"class" matchingName:@"h-entry" allowPartial:YES];

		NSString* permalink = [self permalinkInNode:entry1 requiringPublishedDate:NO];
		if ((entry1 == nil) && (permalink == nil)) {
			HTMLNode* article_node = [self articleWithPermalinkInNode:root1];
			permalink = [self permalinkInNode:article_node requiringPublishedDate:YES];
		}

		NSURL* entry_url = nil;
		if (permalink.length > 0) {
			entry_url = [[NSURL URLWithString:permalink relativeToURL:blogURL] absoluteURL];
		}
		if (entry_url) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self.warningField.hidden = YES;
			});
			[self downloadPermalink:entry_url originalHost:blogURL.host completion:completion];
			return;
		}

		// no valid link found
		dispatch_async(dispatch_get_main_queue(), ^{
			if ((entry1 == nil) && (permalink.length == 0)) {
				[self showWarning:@"This theme does not support previews"];
			}
			else {
				[self showWarning:@"Error parsing permalink in template"];
			}
			completion(nil, nil);
		});
	}];
	[task resume];
}

-(NSString *) serializeDocument:(HTMLParser *)parser
{
	return [[parser doc] rawContents];
}

- (void) downloadPermalink:(NSURL *)entryURL originalHost:(NSString *)originalHost completion:(void (^)(NSString* updatedHTML, NSURL* baseURL))completion
{
	// create request to ignore cache and always fetch latest page
	NSURLRequest* request = [NSURLRequest requestWithURL:entryURL
											 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
										 timeoutInterval:60.0];
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request
																completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
		if (error) {
			NSLog(@"Error downloading %@: %@", entryURL, error);
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showWarning:@"Error downloading permalink template"];
				completion(nil, nil);
			});
			return;
		}
		
		// parse the page
		NSString* entryHTML = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSError* parseError = nil;
		HTMLParser* parser2 = [[HTMLParser alloc] initWithString:entryHTML error:&parseError];
		
		// normalize link tags in head and body to absolute URLs
		NSArray* link_tags = [[parser2 head] findChildTags:@"link"];
		for (HTMLNode* link_node in link_tags) {
			NSString* href = [link_node getAttributeNamed:@"href"];
			if ([href hasPrefix:@"/"]) {
				NSString* full_href = [NSString stringWithFormat:@"https://%@%@", originalHost, href];
				[link_node setAttributeNamed:@"href" value:full_href];
			}
		}

		HTMLNode* root2 = [parser2 body];
		HTMLNode* entry2 = [root2 findChildWithAttribute:@"class" matchingName:@"h-entry" allowPartial:YES];
		if (entry2 == nil) {
			entry2 = [self articleWithPermalinkInNode:root2];
		}
		if (entry2 == nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showWarning:@"This theme does not support previews"];
				completion(nil, nil);
			});
			return;
		}

		// remove existing blog post children
		for (HTMLNode* child in [entry2 children]) {
			[child detach];
		}

		// add placeholder content
		[entry2 setRawContents:@"<h1 class=\"p-name\">[TITLE]</h1>\n[CONTENT]\n[PHOTOS]"];

		// serialize back to HTML
		NSString *updatedHTML = [self serializeDocument:parser2];

		// save theme HTML to app support templates
		NSString* filePath = [self templatePathForHostname:originalHost];
		NSError* writeError = nil;
		[updatedHTML writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if (writeError) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showWarning:@"Error saving template HTML"];
			});
			NSLog(@"Error writing template %@: %@", filePath, writeError);
		}

		// return on main thread
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(updatedHTML, entryURL);
		});
	}];
	[task resume];
}

- (NSString *) currentTemplatePath
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	NSURL* blog_url = [NSURL URLWithString:destination_uid];
	return [self templatePathForHostname:blog_url.host];
}

- (NSString *) templatePathForHostname:(NSString *)host
{
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString* support_folder = paths.firstObject;
	NSString* app_name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSString* templates_dir;
	
	templates_dir = [support_folder stringByAppendingPathComponent:app_name];
	templates_dir = [templates_dir stringByAppendingPathComponent:@"Templates"];

	NSError* error = nil;
	[[NSFileManager defaultManager] createDirectoryAtPath:templates_dir withIntermediateDirectories:YES attributes:nil error:&error];

	NSString* filename = [host stringByAppendingString:@".html"];
	return [templates_dir stringByAppendingPathComponent:filename];
}

#pragma mark -

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
			// also make sure our file isn't accidentally a folder
			BOOL is_dir = NO;
			if ([[NSFileManager defaultManager] fileExistsAtPath:full_path isDirectory:&is_dir] && !is_dir) {
				NSError* error = nil;
				[[NSFileManager defaultManager] removeItemAtPath:full_path error:&error];
			}
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

- (void) updatedBlogNotification:(NSNotification *)notification
{
	// simulate checkbox to re-download theme if needed
	[self useThemeChanged:self.useThemeCheckbox];
}

- (void) renderPreview
{
	[self renderPreviewTitle:gCurrentPreviewTitle markdown:gCurrentPreviewMarkdown photos:gCurrentPreviewPhotos];
}

- (void) renderPreviewTitle:(NSString *)title markdown:(NSString *)markdown photos:(NSArray *)photos
{
	if ((title == nil) || (markdown == nil)) {
		return;
	}
	
	NSString* template_html = nil;
	
	// load theme template if enabled
	if (self.useThemeCheckbox.state == NSControlStateValueOn) {
		NSString* template_path = [self currentTemplatePath];
		NSString* html = [NSString stringWithContentsOfFile:template_path encoding:NSUTF8StringEncoding error:NULL];
		if (html) {
			template_html = html;
		}
	}
	
	if (template_html == nil) {
		NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Preview" ofType:@"html"];
		template_html = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];
	}
	
	NSURL* base_url = nil;
	NSMutableString* photos_html = [[NSMutableString alloc] init];
	for (RFPhoto* photo in photos) {
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

- (NSAttributedString *) makeString:(NSString *)string withIcon:(NSString *)symbolName
{
	// get the SF Symbol image (macOS 11+)
	NSImage *symbolImage = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
	if (!symbolImage) {
 		// fallback if symbol is invalid
		return [[NSAttributedString alloc] initWithString:string];
	}
	// set size for icon
	CGFloat iconSize = 16;
	symbolImage.size = NSMakeSize(iconSize, iconSize);

	// create the text attachment
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	attachment.image = symbolImage;
	// Adjust baseline alignment
	attachment.bounds = CGRectMake(0, -3, iconSize, iconSize);

	// build the attributed string
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

	// icon
	NSAttributedString *iconString = [NSAttributedString attributedStringWithAttachment:attachment];
	[result appendAttributedString:iconString];

	// space
	[result appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];

	// text
	NSAttributedString *textString = [[NSAttributedString alloc] initWithString:string attributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:13] }];
	[result appendAttributedString:textString];

	return result;
}

#pragma mark -

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
