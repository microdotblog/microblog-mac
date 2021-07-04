//
//  RFExportController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFExportController.h"

#import "RFClient.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "RFSettings.h"
#import "RFPost.h"
#import "UUDate.h"

@implementation RFExportController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Export"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupWindow];
	[self setupProgress];
	[self downloadPostsInBackgroundWithOffset:0];
}

- (void) setupWindow
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid != nil) {
		NSString* s = [NSString stringWithFormat:@"Export for %@", destination_uid];
		[self.window setTitle:s];
	}
}

- (void) setupProgress
{
	[self.progressBar setIndeterminate:YES];
	[self.progressBar startAnimation:nil];
}

- (void) downloadPostsInBackgroundWithOffset:(NSInteger)offset
{
	[self performSelectorInBackground:@selector(downloadPosts:) withObject:@(offset)];
}

- (void) downloadPosts:(NSNumber *)offset
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSInteger limit = 200;
	
	NSDictionary* args;
	NSString* channel = @"default";
	
	args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"mp-channel": channel,
		@"limit": @(limit),
		@"offset": offset
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([offset integerValue] > 0) {
			NSString* s = [NSString stringWithFormat:@"Downloading posts (%@)...", offset];
			RFDispatchMainAsync (^{
				[self.statusField setStringValue:s];
			});
		}
		
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFPost* post = [[RFPost alloc] init];
				NSDictionary* props = [item objectForKey:@"properties"];
				post.title = [[props objectForKey:@"name"] firstObject];
				post.text = [[props objectForKey:@"content"] firstObject];
				post.url = [[props objectForKey:@"url"] firstObject];

				NSString* date_s = [[props objectForKey:@"published"] firstObject];
				post.postedAt = [NSDate uuDateFromRfc3339String:date_s];

				NSString* status = [[props objectForKey:@"post-status"] firstObject];
				post.isDraft = [status isEqualToString:@"draft"];
				post.channel = channel;
				
				post.categories = @[];
				if ([[props objectForKey:@"category"] count] > 0) {
					post.categories = [props objectForKey:@"category"];
				}

				[new_posts addObject:post];
			}
			
			// wait a second so we don't hit the server too much
			[NSThread sleepForTimeInterval:1];
			
			RFDispatchMainAsync (^{
				if (new_posts.count == 0) {
					NSLog (@"Downloading posts... done.");
				}
				else {
					NSInteger new_offset = [offset integerValue] + limit;
					[self downloadPostsInBackgroundWithOffset:new_offset];
				}
			});
		}
	}];
}

- (IBAction) cancel:(id)sender
{
	[self.window performClose:nil];
}

@end
