//
//  RFBookmarkController.m
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFBookmarkController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"

@implementation RFBookmarkController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Bookmark"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupClipboard];
}

- (void) setupClipboard
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSArray* objs = [pb readObjectsForClasses:@[ [NSString class] ] options:@{}];
	NSString* url = [objs firstObject];
	if (url && [url containsString:@"http"]) {
		self.urlField.stringValue = url;
	}
}

- (IBAction) saveBookmark:(id)sender
{
	[self.progressSpinner startAnimation:nil];
	
	NSString* url = self.urlField.stringValue;

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	NSDictionary* args = @{
		@"h": @"entry",
		@"content": @"",
		@"bookmark-of": url
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self.window performClose:nil];
		});
	}];
}

@end
