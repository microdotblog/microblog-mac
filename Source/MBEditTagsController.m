//
//  MBEditTagsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/27/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBEditTagsController.h"

#import "MBBookmark.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

@implementation MBEditTagsController

- (id) initWithBookmarkID:(NSString *)bookmarkID
{
	self = [super initWithWindowNibName:@"EditTags"];
	if (self) {
		self.bookmarkID = bookmarkID;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self fetchBookmark];
}

- (void) fetchBookmark
{
	[self.progressSpinner startAnimation:nil];
	
	// get current tags for this bookmark
	RFClient* client = [[RFClient alloc] initWithFormat:@"/posts/bookmarks/%@", self.bookmarkID];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSDictionary* info = [[response.parsedResponse objectForKey:@"items"] firstObject];

			MBBookmark* b = [[MBBookmark alloc] init];
			b.bookmarkID = [info objectForKey:@"id"];
			b.flatTags = [info objectForKey:@"tags"];
			
			self.bookmark = b;
			
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				self.tagsField.stringValue = self.bookmark.flatTags;
			});
		}
	}];
}

- (IBAction) cancel:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) update:(id)sender
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* params = @{
		@"tags": self.tagsField.stringValue
	};
	
	// save tags to server
	RFClient* client = [[RFClient alloc] initWithFormat:@"/posts/bookmarks/%@", self.bookmarkID];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync ((^{
			NSDictionary* info = @{
				kTagsDidUpdateIDKey: self.bookmarkID,
				kTagsDidUpdateTagsKey: self.bookmark.flatTags
			};
			[[NSNotificationCenter defaultCenter] postNotificationName:kTagsDidUpdateNotification object:self userInfo:info];
			[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
		}));
	}];
}

@end
