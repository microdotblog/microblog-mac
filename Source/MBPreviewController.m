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
	
	NSError* error = nil;
	NSString* html = [MMMarkdown HTMLStringWithMarkdown:markdown error:&error];
	if (error == nil) {
		if (![html isEqualToString:self.html]) {
			self.html = html;
			[self.webview loadHTMLString:html baseURL:nil];
		}
	}
}

@end
