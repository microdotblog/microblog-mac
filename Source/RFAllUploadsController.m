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
#import "MBCollection.h"
#import "RFClient.h"
#import "RFUpload.h"
#import "MBUploadProgress.h"
#import "RFPhoto.h"
#import "RFPhotoCell.h"
#import "UUDate.h"
#import "RFMacros.h"
#import "NSImage+Extras.h"
#import "NSAlert+Extras.h"
#import "NSString+Extras.h"
#import "NSCollectionView+Extras.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

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
    
    [self fetchUploads];
	[self fetchCollections];
}

- (void) viewDidAppear
{
	[super viewDidAppear];
	
	RFDispatchSeconds(0.5, ^{
		// run in a bit to make sure resonder chain is set up
		[self.view.window makeFirstResponder:self.collectionView];
	});
}

- (void) setupCollectionView
{
	NSMutableArray* types = [[NSFilePromiseReceiver readableDraggedTypes] mutableCopy];
	[types addObject:NSPasteboardTypeFileURL];
	[self.collectionView registerForDraggedTypes:types];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectPhotoCellNotification:) name:kSelectPhotoCellNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteSelectedPhotoNotification:) name:kDeleteSelectedPhotoNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFromCollectionNotification:) name:kRemoveFromCollectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showCollectionNotification:) name:kShowCollectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadDidUpdateNotification:) name:kUploadDidUpdateNotification object:nil];
}

- (void) fetchUploads
{
	[self fetchUploadsForSearch:@""];
}

- (void) fetchUploadsForSearch:(NSString *)search
{
	self.allPosts = @[];
	self.blogNameButton.hidden = YES;
	self.collectionView.animator.alphaValue = 0.0;

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"limit": @200
	};
	
	if (search.length > 0) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:search forKey:@"filter"];
		[new_args removeObjectForKey:@"limit"];
		args = new_args;
	}
	
	if (self.selectedCollection) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:self.selectedCollection.url forKey:@"microblog-collection"];
		args = new_args;
	}

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			__block NSMutableArray* new_posts = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFUpload* upload = [[RFUpload alloc] init];
				upload.url = [item objectForKey:@"url"];
				upload.poster_url = [item objectForKey:@"poster"];
				upload.alt = [item objectForKey:@"alt"];
				upload.isAI = [[item objectForKey:@"microblog-ai"] boolValue];
				
				NSDictionary* cdn = [item objectForKey:@"cdn"];
				if (cdn) {
					NSString* medium_url = [cdn objectForKey:@"medium"];
					NSString* small_url = [cdn objectForKey:@"small"];
					if (small_url) {
						upload.thumbnail_url = small_url;
					}
					else if (medium_url) {
						upload.thumbnail_url = medium_url;
					}
				}

				upload.width = [[item objectForKey:@"width"] integerValue];
				upload.height = [[item objectForKey:@"height"] integerValue];

				NSString* date_s = [item objectForKey:@"published"];
				upload.createdAt = [NSDate uuDateFromRfc3339String:date_s];

				[new_posts addObject:upload];
			}
			
			RFDispatchMainAsync (^{
				self.allPosts = new_posts;
				[self.collectionView reloadData];
//				[self.collectionView.collectionViewLayout invalidateLayout];
//				[self.collectionView layoutSubtreeIfNeeded];
				[self setupBlogName];
				[self stopLoadingSidebarRow];
				self.blogNameButton.hidden = NO;
				self.collectionView.animator.alphaValue = 1.0;
			});
		}
	}];
}

- (void) fetchCollections
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"q": @"source",
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSArray* items = [[response parsedResponse] objectForKey:@"items"];
			NSString* s = @"";
			if (items.count > 0) {
				if (items.count == 1) {
					s = @"1 collection";
				}
				else {
					s = [NSString stringWithFormat:@"%lu collections", (unsigned long)items.count];
				}
			}
			RFDispatchMain(^{
				[self setCollectionsTitle:s includeCancel:NO];
			});
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

- (void) setCollectionsTitle:(NSString *)title includeCancel:(BOOL)includeCancel
{
	if (includeCancel) {
		// create an NSTextAttachment for the SF Symbol
		NSTextAttachment* attachment = [[NSTextAttachment alloc] init];
		attachment.image = [NSImage imageWithSystemSymbolName:@"xmark.circle.fill" accessibilityDescription:@"Clear"];
		attachment.image.size = NSMakeSize(16, 16);
		
		// create an attributed string with the SF Symbol and title
		NSAttributedString* attachment_s = [NSAttributedString attributedStringWithAttachment:attachment];
		NSMutableAttributedString* title_s = [[NSMutableAttributedString alloc] initWithAttributedString:attachment_s];
		NSString* title_with_space = [NSString stringWithFormat:@" %@", title];
		[title_s appendAttributedString:[[NSAttributedString alloc] initWithString:title_with_space]];
		
		self.collectionsButton.attributedTitle = title_s;
	}
	else {
		self.collectionsButton.title = title;
	}
	
	self.collectionsButton.hidden = NO;
}

#pragma mark -

- (IBAction) blogNameClicked:(id)sender
{
    [self showBlogsMenu];
}

- (IBAction) showInfo:(id)sender
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];
	
	NSString* alt = up.alt;
	if (alt == nil) {
		alt = @"";
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kShowInfoNotification object:self userInfo:@{
		kInfoURLKey: up.url,
		kInfoTextKey: alt,
		kInfoAIKey: @(up.isAI)
	}];
}

- (IBAction) copyLinkOrHTML:(id)sender
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	RFPhotoCell* cell = (RFPhotoCell *)[self collectionView:self.collectionView itemForRepresentedObjectAtIndexPath:index_path];
	[cell copyHTML:sender];
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

	self.selectedCollection = nil;
	
	[self fetchUploads];
	[self fetchCollections];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self fetchUploads];
}

- (void) uploadFilesNotification:(NSNotification *)notification
{
	NSArray* paths = [notification.userInfo objectForKey:kUploadFilesPathsKey];

	if ([paths count] > 10) {
		[NSAlert rf_showOneButtonAlert:@"Could Not Upload Files" message:@"Only 10 files can be uploaded at once." button:@"OK" completionHandler:NULL];
		return;
	}

	NSMutableArray<NSURL *>* video_urls = [NSMutableArray array];
	NSMutableArray<NSString *>* regular_paths = [NSMutableArray array];

	for (id path in paths) {
		NSURL* file_url = nil;
		NSString* path_string = nil;

		if ([path isKindOfClass:[NSURL class]]) {
			file_url = (NSURL *)path;
			if (file_url.isFileURL) {
				path_string = file_url.path;
			}
		}
		else if ([path isKindOfClass:[NSString class]]) {
			path_string = (NSString *)path;
			file_url = [NSURL fileURLWithPath:path_string];
		}

		if (file_url == nil) {
			continue;
		}

		if ([self isVideoFileURL:file_url]) {
			[video_urls addObject:file_url];
		}
		else if (path_string) {
			[regular_paths addObject:path_string];
		}
	}

	void (^startPhotoUploads)(void) = ^{
		if ([regular_paths count] == 0) {
			return;
		}

		NSMutableArray* new_photos = [regular_paths mutableCopy];
		[self uploadNextPhoto:new_photos];
		[self showUploadProgress];
	};

	if ([video_urls count] > 0) {
		__weak typeof(self) weakSelf = self;
		[self uploadVideoURLs:video_urls completion:^{
			__strong typeof(self) strongSelf = weakSelf;
			if (!strongSelf) {
				return;
			}
			if ([regular_paths count] == 0) {
				return;
			}

			RFDispatchMainAsync(^{
				startPhotoUploads();
			});
		}];
	}

	if ([video_urls count] == 0) {
		startPhotoUploads();
	}
}

- (void) selectPhotoCellNotification:(NSNotification *)notification
{
	RFPhotoCell* cell = [notification.userInfo objectForKey:kSelectPhotoCellKey];

	// deselect all
	for (NSInteger i = 0; i < self.allPosts.count; i++) {
		NSIndexPath* index_path = [NSIndexPath indexPathForItem:i inSection:0];
		NSSet* deselect_set = [NSSet setWithObject:index_path];
		[self collectionView:self.collectionView didDeselectItemsAtIndexPaths:deselect_set];
	}
	
	// find clicked cell and select it
	for (NSInteger i = 0; i < self.allPosts.count; i++) {
		RFUpload* up = [self.allPosts objectAtIndex:i];
		if ([cell.url isEqualToString:up.url]) {
			NSIndexPath* index_path = [NSIndexPath indexPathForItem:i inSection:0];
			NSSet* select_set = [NSSet setWithObject:index_path];
			[self.self.collectionView deselectAll:nil];
			[self.collectionView selectItemsAtIndexPaths:select_set scrollPosition:NSCollectionViewScrollPositionNone];
			[self collectionView:self.collectionView didSelectItemsAtIndexPaths:select_set];
			break;
		}
	}
}

- (void) deleteSelectedPhotoNotification:(NSNotification *)notification
{
	[self delete:nil];
}

- (void) deleteFromCollectionNotification:(NSNotification *)notification
{
	if (self.selectedCollection) {
		NSString* url = [notification.userInfo objectForKey:kRemoveFromCollectionURLKey];
		[self removePhotoURL:url fromCollection:self.selectedCollection];
	}
}

- (void) showCollectionNotification:(NSNotification *)notification
{
	MBCollection* c = [notification.userInfo objectForKey:kCollectionKey];
	self.selectedCollection = c;
	[self setCollectionsTitle:c.name includeCancel:YES];

	self.searchField.enabled = NO;
	self.searchField.stringValue = @"";
	
	[self fetchUploads];
}

- (void) uploadDidUpdateNotification:(NSNotification *)notification
{
	[self fetchUploads];
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length == 0) {
		// get everything
		[self fetchUploads];
	}
	else if (s.length >= 4) {
		// only to server if query not too short
		[self fetchUploadsForSearch:s];
	}
	else {
		// for short keywords we don't support, clear view
		self.allPosts = @[];
		[self.collectionView reloadData];
	}
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(copyLinkOrHTML:)) {
		[item setTitle:@"Copy HTML"];
		NSSet* index_paths = [self.collectionView selectionIndexPaths];
		return ([index_paths count] > 0);
	}
	
	return YES;
}

#pragma mark -

- (IBAction) promptForUpload:(id)sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.allowedContentTypes = @[UTTypeImage, UTTypeMovie];
	panel.allowsMultipleSelection = YES;
	NSModalResponse response = [panel runModal];
	if (response == NSModalResponseOK) {
		NSMutableArray* selected_paths = [NSMutableArray array];
		for (NSURL* url in panel.URLs) {
			NSString* path = url.path;
			if (path.length > 0) {
				[selected_paths addObject:path];
			}
		}
		if ([selected_paths count] > 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: selected_paths }];
		}
	}
}

- (void) uploadVideoURLs:(NSArray<NSURL *> *)urls
{
	[self uploadVideoURLs:urls completion:nil];
}

- (void) uploadVideoURLs:(NSArray<NSURL *> *)urls completion:(void (^)(void))handler
{
	NSMutableArray<NSURL *>* queue = [urls mutableCopy];
	[self uploadNextVideoURL:queue completion:handler];
}

- (void) uploadNextVideoURL:(NSMutableArray<NSURL *> *)queue completion:(void (^)(void))handler
{
	NSURL* url = [queue lastObject];
	if (url == nil) {
		if (handler) {
			handler();
		}
		return;
	}

	[queue removeLastObject];
	__weak typeof(self) weakSelf = self;
	[self uploadVideoAtURL:url completion:^{
		__strong typeof(self) strongSelf = weakSelf;
		if (!strongSelf) {
			if (handler) {
				handler();
			}
			return;
		}

		[strongSelf uploadNextVideoURL:queue completion:handler];
	}];
}

- (void) uploadVideoAtURL:(NSURL *)url completion:(void (^)(void))handler
{
	[self configureProgressSpinnerForVideoUpload];
	self.blogNameButton.hidden = YES;

	MBUploadProgress* uploader = [[MBUploadProgress alloc] init];
	self.uploader = uploader;

	NSString* path = url.path;
	__weak typeof(self) weakSelf = self;
	__block BOOL didCompleteUpload = NO;
	__block BOOL reportedFailure = NO;

	[uploader uploadFileInBackground:path completion:^(CGFloat percent) {
		__strong typeof(self) strongSelf = weakSelf;
		if (!strongSelf) {
			return;
		}

		if (!didCompleteUpload && percent <= 0.0 && uploader.currentFileID == nil && !reportedFailure) {
			reportedFailure = YES;
			[strongSelf restoreProgressSpinnerAfterVideoUpload];
			strongSelf.uploader = nil;
			[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"The video file could not be opened." button:@"OK" completionHandler:NULL];
			if (handler) {
				handler();
			}
			return;
		}

		strongSelf.progressSpinner.doubleValue = percent;

		if (!didCompleteUpload && percent >= 1.0) {
			didCompleteUpload = YES;
			[uploader uploadFinished:^(BOOL success) {
				__strong typeof(self) innerSelf = weakSelf;
				if (!innerSelf) {
					return;
				}

				if (!success) {
					[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"The video upload failed. Please try again." button:@"OK" completionHandler:NULL];
				}
				else {
					[innerSelf fetchUploads];
				}

				[innerSelf restoreProgressSpinnerAfterVideoUpload];
				innerSelf.uploader = nil;

				if (handler) {
					handler();
				}
			}];
		}
	}];
}

- (void) configureProgressSpinnerForVideoUpload
{
	[self.progressSpinner stopAnimation:nil];
	self.progressSpinner.indeterminate = NO;
	self.progressSpinner.style = NSProgressIndicatorStyleBar;
	self.progressSpinner.displayedWhenStopped = YES;
	self.progressSpinner.minValue = 0.0;
	self.progressSpinner.maxValue = 1.0;
	self.progressSpinner.doubleValue = 0.0;
	self.progressSpinner.hidden = NO;
}

- (void) restoreProgressSpinnerAfterVideoUpload
{
	self.progressSpinner.doubleValue = 0.0;
	self.progressSpinner.indeterminate = YES;
	self.progressSpinner.style = NSProgressIndicatorStyleSpinning;
	self.progressSpinner.displayedWhenStopped = NO;
	[self.progressSpinner stopAnimation:nil];
	self.blogNameButton.hidden = NO;
}

- (BOOL) isVideoFileURL:(NSURL *)url
{
	if (@available(macOS 11.0, *)) {
		NSError* error = nil;
		NSDictionary<NSURLResourceKey, id>* resource_values = [url resourceValuesForKeys:@[NSURLContentTypeKey] error:&error];
		UTType* content_type = resource_values[NSURLContentTypeKey];
		if (content_type == nil) {
			content_type = [UTType typeWithFilenameExtension:url.pathExtension.lowercaseString];
		}
		if (content_type && [content_type conformsToType:UTTypeMovie]) {
			return YES;
		}
	}
	else {
		static NSSet<NSString *>* video_extensions;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			video_extensions = [NSSet setWithArray:@[@"mp4", @"m4v", @"mov", @"avi", @"mpg", @"mpeg", @"mp2", @"mpe", @"mpv", @"mkv", @"wmv"]];
		});
		NSString* extension = url.pathExtension.lowercaseString;
		if (extension.length > 0 && [video_extensions containsObject:extension]) {
			return YES;
		}
	}

	return NO;
}

- (void) uploadNextPhoto:(NSMutableArray *)paths
{
	NSString* filepath = [paths lastObject];
	if (filepath) {
		[paths removeLastObject];

		NSString* e = [[filepath pathExtension] lowercaseString];
		if ([e isEqualToString:@"jpg"] || [e isEqualToString:@"jpeg"]) {
			NSImage* img = [[NSImage alloc] initWithContentsOfFile:filepath];
			NSImage* scaled_img;
			if ([RFSettings isPremium]) {
				scaled_img = [img rf_scaleToSmallestDimension:3000];
			}
			else {
				scaled_img = [img rf_scaleToSmallestDimension:1800];
			}
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];

			[self uploadPhoto:photo completion:^{
				[self finishUpload:filepath];
				[self uploadNextPhoto:paths];
			}];
		}
		else {
			[self uploadFile:filepath completion:^{
				[self finishUpload:filepath];
				[self uploadNextPhoto:paths];
			}];
		}
	}
	else {
		[self hideUploadProgress];
		[self fetchUploads];
	}
}

- (void) uploadPhoto:(RFPhoto *)photo completion:(void (^)(void))handler
{
	NSData* d = [photo jpegData];
	BOOL is_video = NO;
	BOOL is_gif = NO;
	BOOL is_png = NO;
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"mp-destination": destination_uid
	};
	[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args isVideo:is_video isGIF:is_gif isPNG:is_png completion:^(UUHttpResponse* response) {
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
	NSString* content_type = [path mb_contentType];

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
		RFDispatchMainAsync ((^{
			if (response.httpError) {
				NSString* msg = [response.httpError.userInfo objectForKey:@"kUUHttpSessionHttpErrorMessageKey"];
				NSString* s = [NSString stringWithFormat:@"Server returned error: %@", msg];
				[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:s button:@"OK" completionHandler:NULL];
				[self hideUploadProgress];
			}
			else if (image_url == nil) {
				[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"Uploaded URL was blank." button:@"OK" completionHandler:NULL];
				[self hideUploadProgress];
			}
			else {
				handler();
			}
		}));
	}];
}

- (void) finishUpload:(NSString *)path
{
	// clean up if a temp file
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	if ([fm fileExistsAtPath:path isDirectory:&is_dir]) {
		if (!is_dir) {
			NSString* temp_folder = NSTemporaryDirectory();
			if ([path hasPrefix:temp_folder]) {
				NSError* error = nil;
				[fm removeItemAtPath:path error:&error];
			}
		}
	}
}

- (void) showUploadProgress
{
	self.blogNameButton.hidden = YES;
	[self.progressSpinner startAnimation:nil];
}

- (void) hideUploadProgress
{
	[self.progressSpinner stopAnimation:nil];
	self.blogNameButton.hidden = NO;
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (void) openSelectedItem
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];

	if ([up isPhoto]) {
		NSDictionary* info = @{
			kOpenPhotoURLKey: [NSURL URLWithString:up.url],
			kOpenPhotoAltKey: up.alt,
			kOpenPhotoAllowCopyKey: @(YES)
		};
		[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPhotoURLNotification object:self userInfo:info];
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

	self.blogNameButton.hidden = YES;
	[self.progressSpinner startAnimation:nil];
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self.progressSpinner stopAnimation:nil];
			self.blogNameButton.hidden = NO;

			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				NSString* msg = response.parsedResponse[@"error_description"];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Upload" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self fetchUploads];
			}
		});
	}];
}

- (IBAction) showOrResetCollections:(id)sender
{
	if (self.collectionsButton.title.length == 0) {
		return;
	}
	
	if (self.selectedCollection) {
		self.selectedCollection = nil;
		self.searchField.enabled = YES;
		
		[self fetchUploads];
		[self fetchCollections];
	}
	else {
		[[NSApplication sharedApplication] sendAction:@selector(showCollections:) to:nil from:self];
	}
}

- (void) removePhotoURL:(NSString *)url fromCollection:(MBCollection *)collection
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* info = @{
		@"mp-channel": @"collections",
		@"mp-destination": destination_uid,
		@"action": @"update",
		@"url": collection.url,
		@"delete": @{
			@"photo": @[ url ]
		}
	};

	[client postWithObject:info completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self fetchUploads];
			[self notifyCollections];
		});
	}];
}

- (void) notifyCollections
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kUpdateCollectionsNotification object:self];
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
		item.thumbnailImageView.alphaValue = 1.0;
		item.iconView.hidden = YES;
	}
	else if (@available(macOS 11.0, *)) {
		item.thumbnailImageView.image = nil;
		item.iconView.hidden = NO;
		if ([up isVideo]) {
			item.thumbnailImageView.image = up.cachedPoster;
			item.thumbnailImageView.alphaValue = 0.3;
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
	
	item.url = up.url;
	item.poster_url = up.poster_url;
	item.alt = up.alt;
	item.isAI = up.isAI;
	[item setupForURL];
	[item setupForCollection:self.selectedCollection];
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(RFPhotoCell *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];
	if ([up isPhoto]) {
		if (up.cachedImage == nil) {
			// use photos proxy or CDN thumbnail URL
			NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/200/%@", up.url];
			if (up.thumbnail_url) {
				url = up.thumbnail_url;
			}

			[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
					NSImage* img = response.parsedResponse;
					RFDispatchMain(^{
						up.cachedImage = img;
						[collectionView mb_safeReloadAtIndexPath:indexPath];
					});
				}
				else {
					// if thumbnail fails (not on CDN yet), fall back to blog URL
					[UUHttpSession get:up.url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
						if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
							NSImage* img = response.parsedResponse;
							RFDispatchMain(^{
								up.cachedImage = img;
								[collectionView mb_safeReloadAtIndexPath:indexPath];
							});
						}
					}];
				}
			}];
		}
	}
	else if ([up isVideo]) {
		if ((up.cachedPoster == nil) && (up.poster_url.length > 0)) {
			NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/200/%@", up.poster_url];
			[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
					NSImage* img = response.parsedResponse;
					RFDispatchMain(^{
						up.cachedPoster = img;
						[collectionView mb_safeReloadAtIndexPath:indexPath];
					});
				}
			}];
		}
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	// update selection style
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		item.selectionOverlayView.layer.opacity = 0.4;
		item.selectionOverlayView.layer.backgroundColor = [NSColor blackColor].CGColor;
	}
	
	// also notify get info window
	NSIndexPath* index_path = [indexPaths anyObject];
	RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
	NSString* alt = item.alt;
	if (alt == nil) {
		alt = @"";
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:kUpdateInfoNotification object:self userInfo:@{
		kInfoURLKey: item.url,
		kInfoTextKey: alt,
		kInfoAIKey: @(item.isAI)
	}];
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
	return [upload htmlTag];
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
