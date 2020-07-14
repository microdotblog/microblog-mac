//
//  RFAllUploadsController.m
//  Snippets
//
//  Created by Manton Reece on 7/13/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFAllUploadsController.h"

#import "RFConstants.h"
#import "RFSettings.h"
#import "RFBlogsController.h"
#import "RFClient.h"
#import "RFUpload.h"
#import "UUDate.h"
#import "RFMacros.h"

@implementation RFAllUploadsController

- (id) init
{
    self = [super initWithNibName:@"AllUploads" bundle:nil];
    if (self) {
    }
    
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self setupCollectionView];
    [self setupBlogName];
    [self setupNotifications];
    
    [self fetchPosts];
}

- (void) setupCollectionView
{
}

- (void) setupBlogName
{
    NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
    if (s) {
        self.blogNameButton.title = s;
    }
    else {
        self.blogNameButton.title = [RFSettings stringForKey:kAccountDefaultSite];
    }
}

- (void) setupNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closePostingNotification:) name:kClosePostingNotification object:nil];
}

- (void) fetchPosts
{
	self.allPosts = @[];
	self.blogNameButton.hidden = YES;
	[self.progressSpinner startAnimation:nil];
	self.collectionView.animator.alphaValue = 0.0;

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFUpload* upload = [[RFUpload alloc] init];
				upload.url = [item objectForKey:@"url"];

				upload.width = [[item objectForKey:@"width"] integerValue];
				upload.height = [[item objectForKey:@"height"] integerValue];

				NSString* date_s = [item objectForKey:@"published"];
				upload.createdAt = [NSDate uuDateFromRfc3339String:date_s];

				[new_posts addObject:upload];
			}
			
			RFDispatchMainAsync (^{
				self.allPosts = new_posts;
				[self.collectionView reloadData];
				[self.progressSpinner stopAnimation:nil];
				[self setupBlogName];
				self.blogNameButton.hidden = NO;
				self.collectionView.animator.alphaValue = 1.0;
			});
		}
	}];
}

- (IBAction) blogNameClicked:(id)sender
{
    [self showBlogsMenu];
}

- (void) showBlogsMenu
{
    if (self.blogsMenuPopover) {
        [self hideBlogsMenu];
    }
    else {
        if (![RFSettings boolForKey:kExternalBlogIsPreferred]) {
            RFBlogsController* blogs_controller = [[RFBlogsController alloc] init];
            
            self.blogsMenuPopover = [[NSPopover alloc] init];
            self.blogsMenuPopover.contentViewController = blogs_controller;
            self.blogsMenuPopover.behavior = NSPopoverBehaviorTransient;
            self.blogsMenuPopover.delegate = self;

            NSRect r = self.blogNameButton.bounds;
            [self.blogsMenuPopover showRelativeToRect:r ofView:self.blogNameButton preferredEdge:NSRectEdgeMaxY];
        }
    }
}

- (void) hideBlogsMenu
{
    if (self.blogsMenuPopover) {
        [self.blogsMenuPopover performClose:nil];
        self.blogsMenuPopover = nil;
    }
}

- (void) popoverDidClose:(NSNotification *)notification
{
    self.blogsMenuPopover = nil;
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
    [self setupBlogName];
    [self hideBlogsMenu];
    [self fetchPosts];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self fetchPosts];
}

@end
