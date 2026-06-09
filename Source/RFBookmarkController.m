//
//  RFBookmarkController.m
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFBookmarkController.h"

#import "MBRobotsModel.h"
#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "RFSettings.h"
#import "Micro_blog-Swift.h"

static NSString* const kBookmarkSummaryPrompt = @"Summarize the following text in one short sentence. Do not start the summary with the text \"The author\" or \"The writer\" or \"The speaker\".\n\n%@";

@interface RFBookmarkController ()

@property (assign, nonatomic) BOOL isSaving;

@end

@implementation RFBookmarkController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Bookmark"];
	if (self) {
	}
	
	return self;
}

- (instancetype) initWithURL:(NSString *)url
{
	self = [self init];
	if (self) {
		self.initialURL = url;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	self.statusField.hidden = YES;
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

- (void) showBookmarkWindow
{
	[self prepareBookmarkWindowWithURL:self.initialURL];
	[self showWindow:nil];
}

- (void) showBookmarkWindowWithURL:(NSString *)url
{
	self.initialURL = url;
	[self prepareBookmarkWindowWithURL:url];
	[self showWindow:nil];
}

- (void) prepareBookmarkWindowWithURL:(NSString *)url
{
	[self window];

	self.isSaving = NO;
	[self.progressSpinner stopAnimation:nil];
	self.statusField.hidden = YES;
	self.statusField.stringValue = @"";

	if (url.length > 0) {
		self.urlField.stringValue = url;
	}
	else {
		self.urlField.stringValue = @"";
		[self setupClipboard];
	}
}

- (IBAction) saveBookmark:(id)sender
{
	if (self.isSaving) {
		return;
	}

	self.isSaving = YES;
	[self.progressSpinner startAnimation:nil];

	NSString* url = self.urlField.stringValue;

	if (![self canSummarizeBookmark]) {
		[self saveBookmarkWithURLString:url summary:@""];
		return;
	}

	[self updateStatus:@"Downloading page..."];
	[self downloadHTMLForURLString:url completion:^(NSString* html) {
		[self summaryForBookmarkHTML:html urlString:url completion:^(NSString* summary) {
			[self saveBookmarkWithURLString:url summary:summary];
		}];
	}];
}

- (void) downloadHTMLForURLString:(NSString *)urlString completion:(void (^)(NSString* html))completion
{
	NSURL* url = [NSURL URLWithString:urlString];
	if (url == nil) {
		completion(@"");
		return;
	}

	NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
	NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
		if (error || (data.length == 0)) {
			NSLog(@"Error downloading bookmark HTML %@: %@", urlString, error);
			RFDispatchMainAsync (^{
				completion(@"");
			});
			return;
		}

		NSString* html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (html == nil) {
			html = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
		}

		RFDispatchMainAsync (^{
			completion(html ?: @"");
		});
	}];
	[task resume];
}

- (BOOL) canSummarizeBookmark
{
	return [RFSettings boolForKey:kIsUsingAI] && [MBRobotsModel isLocalModelAvailable];
}

- (void) summaryForBookmarkHTML:(NSString *)html urlString:(NSString *)urlString completion:(void (^)(NSString* summary))completion
{
	if ((html.length == 0) || ![self canSummarizeBookmark]) {
		completion(@"");
		return;
	}

	[self updateStatus:@"Summarizing text..."];
	[MBBookmarkReadability textContentFromHTML:html baseURLString:urlString completion:^(NSString* text) {
		if (text.length == 0) {
			completion(@"");
			return;
		}

		NSString* prompt = [NSString stringWithFormat:kBookmarkSummaryPrompt, text];
		[MBRobotsModel runPrompt:prompt completion:^(NSString* result) {
			NSString* summary = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			completion(summary ?: @"");
		}];
	}];
}

- (void) saveBookmarkWithURLString:(NSString *)urlString summary:(NSString *)summary
{
	[self updateStatus:@"Bookmarking..."];

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	NSMutableDictionary* args = [@{
		@"h": @"entry",
		@"content": @"",
		@"bookmark-of": urlString
	} mutableCopy];

	if (summary.length > 0) {
		args[@"summary"] = summary;
	}

	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			self.isSaving = NO;
			[self.progressSpinner stopAnimation:nil];
			[self.window performClose:nil];
		});
	}];
}

- (void) updateStatus:(NSString *)status
{
	self.statusField.hidden = NO;
	self.statusField.stringValue = status;
}

@end
