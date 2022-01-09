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
	
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorWindowTextDidChangeNotification:) name:kEditorWindowTextDidChangeNotification object:nil];
}

- (void) editorWindowTextDidChangeNotification:(NSNotification *)notification
{
	NSString* title = [notification.userInfo objectForKey:kEditorWindowTextTitleKey];
	NSString* markdown = [notification.userInfo objectForKey:kEditorWindowTextMarkdownKey];
	
	NSString* template_file = [[NSBundle mainBundle] pathForResource:@"Preview" ofType:@"html"];
	NSString* template_html = [NSString stringWithContentsOfFile:template_file encoding:NSUTF8StringEncoding error:NULL];
	
	NSError* error = nil;
	NSString* content_html = [MMMarkdown HTMLStringWithMarkdown:markdown error:&error];
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

@end
