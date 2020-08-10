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
#import "RFPhotoCell.h"
#import "RFPhotoZoomController.h"
#import "UUDate.h"
#import "RFMacros.h"

static NSString* const kPhotoCellIdentifier = @"PhotoCell";

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
	[self.collectionView registerForDraggedTypes:@[ NSPasteboardTypeString ]];
	[self.collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
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

- (void) openSelectedItem
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];

	RFPhotoZoomController* controller = [[RFPhotoZoomController alloc] initWithURL:up.url];
	[controller showWindow:nil];
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.allPosts.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];
	
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	item.thumbnailImageView.image = up.cachedImage;

	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(RFPhotoCell *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];
	if (up.cachedImage == nil) {
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/200/%@", up.url];

		[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				NSImage* img = response.parsedResponse;
				RFDispatchMain(^{
					up.cachedImage = img;
					[collectionView reloadItemsAtIndexPaths:[NSSet setWithCollectionViewIndexPath:indexPath]];
				});
			}
		}];
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		item.selectionOverlayView.layer.opacity = 0.4;
		item.selectionOverlayView.layer.backgroundColor = [NSColor blackColor].CGColor;
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		item.selectionOverlayView.layer.opacity = 0.0;
		item.selectionOverlayView.layer.backgroundColor = nil;
	}
}

#pragma mark -

- (id<NSPasteboardWriting>) collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath
{
	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];

	NSString* s = [NSString stringWithFormat:@"<img src=\"%@\" />", up.url];
	
	return s;
}

- (BOOL) collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event
{
	return YES;
}

@end
