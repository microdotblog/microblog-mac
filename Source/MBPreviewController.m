//
//  MBPreviewController.m
//  Micro.blog
//
//  Created by Manton Reece on 1/8/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBPreviewController.h"

#import "RFConstants.h"
#import "MMMarkdown.h"

// static storage for class-wide preview data
static NSString* gCurrentPreviewTitle = nil;
static NSString* gCurrentPreviewMarkdown = nil;

@implementation MBPreviewController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Preview"];
	if (self) {
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
}

- (void) setupInitialRender
{
	if (gCurrentPreviewTitle && gCurrentPreviewMarkdown) {
		[self renderPreviewTitle:gCurrentPreviewTitle markdown:gCurrentPreviewMarkdown];
	}
}

+ (void) setCurrentPreviewTitle:(NSString *)title markdown:(NSString *)markdown
{
	gCurrentPreviewTitle = [title copy];
	gCurrentPreviewMarkdown = [markdown copy];
}

- (void) editorWindowTextDidChangeNotification:(NSNotification *)notification
{
	if ([self.window isVisible]) {
		NSString* title = [notification.userInfo objectForKey:kEditorWindowTextTitleKey];
		NSString* markdown = [notification.userInfo objectForKey:kEditorWindowTextMarkdownKey];
		
		[self renderPreviewTitle:title markdown:markdown];
	}
}

- (void) renderPreviewTitle:(NSString *)title markdown:(NSString *)markdown
{
	NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Preview" ofType:@"html"];
	NSString* template_html = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];
	
	NSError* error = nil;
	NSString* content_html = [MMMarkdown HTMLStringWithMarkdown:markdown extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
	if (error == nil) {
		NSString* html = template_html;
		html = [html stringByReplacingOccurrencesOfString:@"[TITLE]" withString:title];
		html = [html stringByReplacingOccurrencesOfString:@"[CONTENT]" withString:content_html];
		
		if (![html isEqualToString:self.html]) {
			self.html = html;
			[self.webview loadHTMLString:html baseURL:nil];
		}
	}
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
