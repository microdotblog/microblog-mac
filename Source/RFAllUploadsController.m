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
#import "RFPhoto.h"
#import "RFPhotoCell.h"
#import "RFPhotoZoomController.h"
#import "UUDate.h"
#import "RFMacros.h"
#import "NSImage+Extras.h"
#import "NSAlert+Extras.h"

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
	[self.collectionView registerForDraggedTypes:@[ NSPasteboardTypeFileURL ]];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadFilesNotification:) name:kUploadFilesNotification object:nil];
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

- (void) uploadFilesNotification:(NSNotification *)notification
{
	NSArray* paths = [notification.userInfo objectForKey:kUploadFilesPathsKey];

	if ([paths count] > 10) {
		[NSAlert rf_showOneButtonAlert:@"Could Not Upload Files" message:@"Only 10 files can be uploaded at once." button:@"OK" completionHandler:NULL];
		return;
	}

	NSMutableArray* new_photos = [NSMutableArray array];

	if ([paths count] > 1) {
		[self.uploadProgressBar setIndeterminate:NO];
		[self.uploadProgressBar setMinValue:1];
		[self.uploadProgressBar setMaxValue:[paths count]];
	}
	else {
		[self.uploadProgressBar setIndeterminate:YES];
	}
	
	for (NSString* filepath in paths) {
		[new_photos addObject:filepath];
	}

	[self uploadNextPhoto:new_photos];
	[self showUploadProgress];
}

- (void) uploadNextPhoto:(NSMutableArray *)paths
{
	NSString* filepath = [paths lastObject];
	if (filepath) {
		[paths removeLastObject];

		if (!self.uploadProgressBar.isIndeterminate) {
			[self.uploadProgressBar setDoubleValue:(self.uploadProgressBar.maxValue - [paths count])];
		}

		NSString* e = [[filepath pathExtension] lowercaseString];
		if ([e isEqualToString:@"jpg"] || [e isEqualToString:@"jpeg"]) {
			NSImage* img = [[NSImage alloc] initWithContentsOfFile:filepath];
			NSImage* scaled_img = [img rf_scaleToSmallestDimension:1800];
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];

			[self uploadPhoto:photo completion:^{
				[self uploadNextPhoto:paths];
			}];
		}
		else {
			[self uploadFile:filepath completion:^{
				[self uploadNextPhoto:paths];
			}];
		}
	}
	else {
		[self hideUploadProgress];
		[self fetchPosts];
	}
}

- (void) uploadPhoto:(RFPhoto *)photo completion:(void (^)(void))handler
{
	NSData* d = [photo jpegData];
	BOOL is_video = NO;
	BOOL is_gif = NO;
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"mp-destination": destination_uid
	};
	[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args isVideo:is_video isGIF:is_gif completion:^(UUHttpResponse* response) {
		NSDictionary* headers = response.httpResponse.allHeaderFields;
		NSString* image_url = headers[@"Location"];
		RFDispatchMainAsync (^{
			if (image_url == nil) {
				[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
				[self hideUploadProgress];
			}
			else {
				handler();
			}
		});
	}];
}

- (void) uploadFile:(NSString *)path completion:(void (^)(void))handler
{
	NSData* d = [NSData dataWithContentsOfFile:path];
	
	NSString* filename = [path lastPathComponent];
	NSString* e = [filename pathExtension];
	NSString* uti = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)e, NULL);
	NSString* content_type = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"mp-destination": destination_uid
	};
	[client uploadFileData:d named:@"file" filename:filename contentType:content_type httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
		NSDictionary* headers = response.httpResponse.allHeaderFields;
		NSString* image_url = headers[@"Location"];
		RFDispatchMainAsync (^{
			if (image_url == nil) {
				[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"Uploaded URL was blank." button:@"OK" completionHandler:NULL];
				[self hideUploadProgress];
			}
			else {
				handler();
			}
		});
	}];
}

- (void) showUploadProgress
{
	[self.uploadProgressBar startAnimation:nil];
	self.uploadProgressBar.hidden = NO;
}

- (void) hideUploadProgress
{
	[self.uploadProgressBar stopAnimation:nil];
	self.uploadProgressBar.hidden = YES;
}

- (void) openSelectedItem
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];

	if ([up isPhoto]) {
		RFPhotoZoomController* controller = [[RFPhotoZoomController alloc] initWithURL:up.url allowCopy:YES];
		[controller showWindow:nil];
	}
	else {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:up.url]];
	}
}

- (void) delete:(id)sender
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	if (index_path) {
		RFUpload* up = [self.allPosts objectAtIndex:index_path.item];
		NSString* s = [up filename];
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Delete \"%@\"?", s];
		sheet.informativeText = @"This upload will be removed from your blog.";
		[sheet addButtonWithTitle:@"Delete"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[self deleteUpload:up];
			}
		}];
	}
}

- (void) deleteUpload:(RFUpload *)upload
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"action": @"delete",
		@"mp-destination": destination_uid,
		@"url": upload.url,
	};

	[self.progressSpinner startAnimation:nil];
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				[self.progressSpinner stopAnimation:nil];
				NSString* msg = response.parsedResponse[@"error_description"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Upload" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchPosts];
			}
		});
	}];
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
	if ([up isPhoto]) {
		item.thumbnailImageView.image = up.cachedImage;
	}
	else if (@available(macOS 11.0, *)) {
		item.thumbnailImageView.image = nil;
		if ([up isVideo]) {
			item.iconView.image = [NSImage imageWithSystemSymbolName:@"film" accessibilityDescription:@""];
		}
		else if ([up isAudio]) {
			item.iconView.image = [NSImage imageWithSystemSymbolName:@"waveform" accessibilityDescription:@""];
		}
		else {
			item.iconView.image = [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:@""];
		}
	}
	else {
		item.thumbnailImageView.image = nil;
	}
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(RFPhotoCell *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];
	if ([up isPhoto]) {
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
	RFUpload* upload = [self.allPosts objectAtIndex:indexPath.item];

	NSString* s;
	if ([upload isPhoto]) {
		s = [NSString stringWithFormat:@"<img src=\"%@\" />", upload.url];
	}
	else if ([upload isVideo]) {
		s = [NSString stringWithFormat:@"<video src=\"%@\" controls=\"controls\" playsinline=\"playsinline\" preload=\"none\"></video>", upload.url];
	}
	else if ([upload isAudio]) {
		s = [NSString stringWithFormat:@"<audio src=\"%@\" controls=\"controls\" preload=\"metadata\" />", upload.url];
	}
	else {
		s = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", upload.url, [upload filename]];
	}

	return s;
}

- (BOOL) collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexes:(NSIndexSet *)indexes withEvent:(NSEvent *)event
{
	return YES;
}

//- (NSDragOperation) collectionView:(NSCollectionView *)collectionView validateDrop:(id <NSDraggingInfo>)draggingInfo proposedIndexPath:(NSIndexPath * _Nonnull * _Nonnull)proposedDropIndexPath dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation
//{
//	return NSDragOperationCopy;
//}
//
//- (BOOL) collectionView:(NSCollectionView *)collectionView acceptDrop:(id <NSDraggingInfo>)draggingInfo indexPath:(NSIndexPath *)indexPath dropOperation:(NSCollectionViewDropOperation)dropOperation
//{
//	return NO;
//}

@end
