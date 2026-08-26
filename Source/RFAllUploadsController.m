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
#import "NSError+Extras.h"
#import "NSString+Extras.h"
#import "NSCollectionView+Extras.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString* const kPhotoCellIdentifier = @"PhotoCell";
static NSInteger const kInitialUploadsLimit = 30;
static NSInteger const kUploadsLimit = 200;
static CGFloat const kUploadCellCornerRadius = 4.0;

@interface RFAllUploadsController () <NSTextFieldDelegate>

@property (assign, nonatomic) BOOL isObservingWindowNotifications;
@property (assign, nonatomic) NSInteger uploadsRequestID;
@property (assign, nonatomic) NSInteger collectionsRequestID;
@property (assign, nonatomic) BOOL isFetchingUploads;
@property (assign, nonatomic) BOOL isCheckingForNewUploads;
@property (assign, nonatomic) BOOL needsUploadsRetry;
@property (copy, nonatomic) NSString* currentSearch;
@property (copy, nonatomic) NSString* loadedUploadsContext;

- (void) fetchInitialUploads;

@end

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
	self.searchField.delegate = self;
	
	[self fetchInitialUploads];
	[self fetchCollections];
}

- (void) viewDidAppear
{
	[super viewDidAppear];

	if (!self.isObservingWindowNotifications && self.view.window != nil) {
		self.isObservingWindowNotifications = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.view.window];
	}
	
	RFDispatchSeconds(0.5, ^{
		// run in a bit to make sure resonder chain is set up
		[self.view.window makeFirstResponder:self.collectionView];
	});
	
	[self startUploadsTimer];
	[self refreshDestinationsCache];
}

- (void) viewDidDisappear
{
	[super viewDidDisappear];

	if (self.isObservingWindowNotifications) {
		self.isObservingWindowNotifications = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}
	
	[self invalidateUploadsTimer];
	[self.uploader cancelUpload];
	self.uploader = nil;
}

- (void) dealloc
{
	if (self.isObservingWindowNotifications) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
	}

	[self invalidateUploadsTimer];
	[self.uploader cancelUpload];
	self.uploader = nil;
}

- (void) setupCollectionView
{
	NSMutableArray* types = [[NSFilePromiseReceiver readableDraggedTypes] mutableCopy];
	[types addObject:NSPasteboardTypeFileURL];
	[self.collectionView registerForDraggedTypes:types];
	[self.collectionView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

	[self registerPhotoCellIfNeededForSearch:@""];
}

- (void) registerPhotoCellIfNeededForSearch:(NSString *)search
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSString* collection_key = self.selectedCollection.url;
	if (collection_key == nil) {
		collection_key = @"";
	}

	NSString* search_key = @"all";
	if (search.length > 0) {
		search_key = @"search";
	}
	NSUserInterfaceItemIdentifier identifier = [NSString stringWithFormat:@"%@-%@-%@-%@", kPhotoCellIdentifier, destination_uid, collection_key, search_key];
	if ([self.photoCellIdentifier isEqualToString:identifier]) {
		return;
	}

	self.photoCellIdentifier = identifier;

	NSNib* nib = [[NSNib alloc] initWithNibNamed:@"PhotoCell" bundle:nil];
	[self.collectionView registerNib:nib forItemWithIdentifier:identifier];
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

	if ([self.blogNameButton isKindOfClass:[RFHostnameButton class]]) {
		((RFHostnameButton*) self.blogNameButton).showsChevron = [RFBlogsController hasMultipleCachedDestinations];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCollectionsNotification:) name:kUpdateCollectionsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadDidUpdateNotification:) name:kUploadDidUpdateNotification object:nil];
}

- (void) fetchUploads
{
	[self fetchUploadsForSearch:@""];
}

- (NSString *) currentSearchFieldString
{
	NSText* editor = self.searchField.currentEditor;
	if (editor) {
		return editor.string ?: @"";
	}
	else {
		return self.searchField.stringValue ?: @"";
	}
}

- (void) replaceUploads:(NSArray *)uploads
{
	[self.collectionView deselectAll:nil];
	self.allPosts = uploads ?: @[];
	[self.collectionView reloadData];
	[self.collectionView.collectionViewLayout invalidateLayout];
	[self.collectionView layoutSubtreeIfNeeded];
}

- (void) appendUploads:(NSArray *)uploads
{
	if (uploads.count == 0) {
		return;
	}

	NSMutableArray* combined_uploads = self.allPosts ? [self.allPosts mutableCopy] : [NSMutableArray array];
	NSMutableSet* existing_urls = [NSMutableSet set];
	for (RFUpload* upload in combined_uploads) {
		if (upload.url.length > 0) {
			[existing_urls addObject:upload.url];
		}
	}

	NSMutableSet* index_paths = [NSMutableSet set];
	for (RFUpload* upload in uploads) {
		if ((upload.url.length == 0) || [existing_urls containsObject:upload.url]) {
			continue;
		}

		NSIndexPath* index_path = [NSIndexPath indexPathForItem:combined_uploads.count inSection:0];
		[combined_uploads addObject:upload];
		[existing_urls addObject:upload.url];
		[index_paths addObject:index_path];
	}

	if (index_paths.count > 0) {
		self.allPosts = combined_uploads;
		[self.collectionView insertItemsAtIndexPaths:index_paths];
	}
}

- (BOOL) responseWasSuccessful:(UUHttpResponse *)response
{
	NSInteger status_code = response.httpResponse.statusCode;
	return (response.httpError == nil && status_code >= 200 && status_code < 300);
}

- (NSString *) errorMessageForResponse:(UUHttpResponse *)response fallback:(NSString *)fallback
{
	if (response.httpError) {
		return [response.httpError mb_networkMessageWithResponse:response.httpResponse];
	}

	NSInteger status_code = response.httpResponse.statusCode;
	if (status_code > 0) {
		NSString* status_text = [NSHTTPURLResponse localizedStringForStatusCode:status_code];
		return [NSString stringWithFormat:@"The server returned HTTP %ld (%@).", (long)status_code, status_text];
	}

	return fallback;
}

- (NSArray *) uploadsFromResponse:(UUHttpResponse *)response
{
	if (![self responseWasSuccessful:response] || ![response.parsedResponse isKindOfClass:[NSDictionary class]]) {
		return nil;
	}

	NSArray* items = [response.parsedResponse objectForKey:@"items"];
	if (![items isKindOfClass:[NSArray class]]) {
		return nil;
	}

	NSMutableArray* new_posts = [NSMutableArray array];
	for (NSDictionary* item in items) {
		if (![item isKindOfClass:[NSDictionary class]]) {
			continue;
		}

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

	return new_posts;
}

- (NSString *) uploadsContextForSearch:(NSString *)search destinationUID:(NSString *)destinationUID collectionURL:(NSString *)collectionURL
{
	return [@[ destinationUID ?: @"", collectionURL ?: @"", search ?: @"" ] componentsJoinedByString:@"\n"];
}

- (void) beginFetchingUploadsForContext:(NSString *)context
{
	self.isFetchingUploads = YES;
	self.needsUploadsRetry = NO;

	if (![context isEqualToString:self.loadedUploadsContext]) {
		self.loadedUploadsContext = nil;
		[self replaceUploads:@[]];
		self.collectionView.alphaValue = 0.0;
	}
}

- (void) finishFetchingUploads
{
	[self setupBlogName];
	[self stopLoadingSidebarRow];
	self.blogNameButton.hidden = NO;
	self.collectionView.alphaValue = 1.0;
}

- (void) fetchRemainingInitialUploadsForDestination:(NSString *)destinationUID requestID:(NSInteger)requestID
{
	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destinationUID,
		@"limit": @(kUploadsLimit - kInitialUploadsLimit),
		@"offset": @(kInitialUploadsLimit)
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		NSArray* remaining_uploads = [self uploadsFromResponse:response];

		RFDispatchMainAsync(^{
			if (requestID != self.uploadsRequestID) {
				return;
			}

			self.isFetchingUploads = NO;
			if (remaining_uploads) {
				self.needsUploadsRetry = NO;
				[self appendUploads:remaining_uploads];
			}
			else {
				self.needsUploadsRetry = YES;
			}
		});
	}];
}

- (void) fetchInitialUploads
{
	self.uploadsRequestID++;
	NSInteger request_id = self.uploadsRequestID;

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSString* context = [self uploadsContextForSearch:@"" destinationUID:destination_uid collectionURL:nil];

	[self registerPhotoCellIfNeededForSearch:@""];
	[self beginFetchingUploadsForContext:context];

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"limit": @(kInitialUploadsLimit)
	};

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		NSArray* initial_uploads = [self uploadsFromResponse:response];

		RFDispatchMainAsync(^{
			if (request_id != self.uploadsRequestID) {
				return;
			}

			if (initial_uploads) {
				self.loadedUploadsContext = context;
				self.needsUploadsRetry = NO;
				[self replaceUploads:initial_uploads];
			}
			else {
				self.needsUploadsRetry = YES;
			}

			[self finishFetchingUploads];

			if (initial_uploads.count == kInitialUploadsLimit) {
				[self fetchRemainingInitialUploadsForDestination:destination_uid requestID:request_id];
			}
			else {
				self.isFetchingUploads = NO;
			}
		});
	}];
}

- (void) fetchUploadsForSearch:(NSString *)search
{
	self.uploadsRequestID++;
	NSInteger request_id = self.uploadsRequestID;

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSString* collection_url = self.selectedCollection.url;
	NSString* context = [self uploadsContextForSearch:search destinationUID:destination_uid collectionURL:collection_url];

	[self registerPhotoCellIfNeededForSearch:search];
	[self beginFetchingUploadsForContext:context];

	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"limit": @(kUploadsLimit)
	};
	
	if (search.length > 0) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:search forKey:@"filter"];
		[new_args removeObjectForKey:@"limit"];
		args = new_args;
	}
	
	if (collection_url.length > 0) {
		NSMutableDictionary* new_args = [args mutableCopy];
		[new_args setObject:collection_url forKey:@"microblog-collection"];
		args = new_args;
	}

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		NSArray* new_posts = [self uploadsFromResponse:response];
			
		RFDispatchMainAsync (^{
			if (request_id != self.uploadsRequestID) {
				return;
			}

			self.isFetchingUploads = NO;
			if (new_posts) {
				self.loadedUploadsContext = context;
				self.needsUploadsRetry = NO;
				[self replaceUploads:new_posts];
			}
			else {
				self.needsUploadsRetry = YES;
			}

			[self finishFetchingUploads];
		});
	}];
}

- (void) refreshUploadsForCurrentFilter
{
	if (self.selectedCollection) {
		[self fetchUploadsForSearch:@""];
		return;
	}

	NSString* search = self.currentSearch ?: @"";
	if (search.length == 0) {
		// get everything
		[self fetchUploadsForSearch:@""];
	}
	else if (search.length >= 4) {
		// only to server if query not too short
		[self fetchUploadsForSearch:search];
	}
	else {
		// for short keywords we don't support, clear view
		self.uploadsRequestID++;
		self.isFetchingUploads = NO;
		self.needsUploadsRetry = NO;
		self.loadedUploadsContext = nil;
		[self registerPhotoCellIfNeededForSearch:@""];
		[self replaceUploads:@[]];
		[self setupBlogName];
		[self stopLoadingSidebarRow];
		self.blogNameButton.hidden = NO;
		self.collectionView.alphaValue = 1.0;
	}
}

- (void) startUploadsTimer
{
	[self invalidateUploadsTimer];
	
	self.uploadsTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(checkForNewUploads:) userInfo:nil repeats:YES];
}

- (void) invalidateUploadsTimer
{
	[self.uploadsTimer invalidate];
	self.uploadsTimer = nil;
}

- (void) checkForNewUploads:(NSTimer *)timer
{
	if (self.selectedCollection || self.currentSearch.length > 0) {
		return;
	}
	if (self.isFetchingUploads || self.isCheckingForNewUploads) {
		return;
	}
	if (self.needsUploadsRetry) {
		[self refreshUploadsForCurrentFilter];
		return;
	}

	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	
	NSDictionary* args = @{
		@"q": @"source",
		@"mp-destination": destination_uid,
		@"limit": @1
	};
	self.isCheckingForNewUploads = YES;
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		NSArray* uploads = [self uploadsFromResponse:response];
		RFUpload* latest_upload = [uploads firstObject];
		NSString* latest_url = latest_upload.url;
		
		RFDispatchMainAsync(^{
			self.isCheckingForNewUploads = NO;
			NSString* current_destination_uid = [RFSettings stringForKey:kCurrentDestinationUID] ?: @"";
			if (self.isFetchingUploads || ![destination_uid isEqualToString:current_destination_uid] || self.selectedCollection || self.currentSearch.length > 0 || latest_url.length == 0) {
				return;
			}

			RFUpload* first_upload = [self.allPosts firstObject];
			NSString* current_url = first_upload.url;
			if (![latest_url isEqualToString:current_url]) {
				[self refreshUploadsForCurrentFilter];
			}
		});
	}];
}

- (void) fetchCollections
{
	self.collectionsRequestID++;
	NSInteger request_id = self.collectionsRequestID;

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
		if ([self responseWasSuccessful:response] && [[response parsedResponse] isKindOfClass:[NSDictionary class]]) {
			NSArray* items = [[response parsedResponse] objectForKey:@"items"];
			if (![items isKindOfClass:[NSArray class]]) {
				return;
			}
			NSString* s = @"";
			NSMutableDictionary* collection_names_by_url = [NSMutableDictionary dictionary];
			if (items.count > 0) {
				if (items.count == 1) {
					s = @"1 collection";
				}
				else {
					s = [NSString stringWithFormat:@"%lu collections", (unsigned long)items.count];
				}

				for (NSDictionary* info in items) {
					NSDictionary* props = [info objectForKey:@"properties"];
					NSString* name = [[props objectForKey:@"name"] firstObject];
					NSString* url = [[props objectForKey:@"url"] firstObject];
					if (url.length > 0) {
						[collection_names_by_url setObject:(name ?: @"") forKey:url];
					}
				}
			}

			RFDispatchMainAsync(^{
				NSString* current_destination_uid = [RFSettings stringForKey:kCurrentDestinationUID] ?: @"";
				if (request_id != self.collectionsRequestID || ![destination_uid isEqualToString:current_destination_uid]) {
					return;
				}

				NSString* selected_url = self.selectedCollection.url;
				NSString* selected_name = nil;
				if (selected_url.length > 0) {
					selected_name = [collection_names_by_url objectForKey:selected_url];
				}
				if (self.selectedCollection && selected_name == nil) {
					self.selectedCollection = nil;
					self.searchField.enabled = YES;
					[self setCollectionsTitle:s includeCancel:NO];
					[self refreshUploadsForCurrentFilter];
				}
				else if (self.selectedCollection) {
					self.selectedCollection.name = selected_name;
					[self setCollectionsTitle:self.selectedCollection.name includeCancel:YES];
				}
				else {
					[self setCollectionsTitle:s includeCancel:NO];
				}
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

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self refreshDestinationsCache];
}

- (void) refreshDestinationsCache
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	[RFBlogsController fetchDestinationsInBackgroundWithCompletion:^(NSArray* destinations) {
		#pragma unused(destinations)
		[self setupBlogName];
	}];
}

- (IBAction) cancelUpload:(id)sender
{
	MBUploadProgress* uploader = self.uploader;
	if (!uploader) {
		[self restoreProgressSpinnerAfterVideoUpload];
		return;
	}

	[uploader cancelUpload];
	self.uploader = nil;
	[self restoreProgressSpinnerAfterVideoUpload];
}

- (IBAction) showInfo:(id)sender
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	if (index_path == nil || index_path.item >= self.allPosts.count) {
		return;
	}

	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];
	if (up.url.length == 0) {
		return;
	}
	
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
	if (index_path == nil || index_path.item >= self.allPosts.count) {
		return;
	}

	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];
	[up ensureDimensionsWithCompletion:^{
		NSString* s = [up htmlTag];

		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:s forType:NSPasteboardTypeString];
	}];
}

- (void) showBlogsMenu
{
	if ([RFSettings boolForKey:kExternalBlogIsPreferred]) {
		return;
	}

	NSMenu* menu = [RFBlogsController blogsMenuWithTarget:[RFBlogsController class] action:@selector(selectDestinationMenuItem:)];
	if (menu.numberOfItems == 0) {
		return;
	}

	NSPoint menu_point = NSMakePoint(0.0, NSMinY(self.blogNameButton.bounds));
	[menu popUpMenuPositioningItem:nil atLocation:menu_point inView:self.blogNameButton];
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self setupBlogName];

	self.selectedCollection = nil;
	self.currentSearch = @"";
	self.searchField.enabled = YES;
	self.searchField.stringValue = @"";
	
	[self fetchUploads];
	[self fetchCollections];
}

- (void) closePostingNotification:(NSNotification *)notification
{
	[self refreshUploadsForCurrentFilter];
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
	self.currentSearch = @"";
	[self setCollectionsTitle:c.name includeCancel:YES];

	self.searchField.enabled = NO;
	self.searchField.stringValue = @"";
	
	[self fetchUploads];
}

- (void) updateCollectionsNotification:(NSNotification *)notification
{
	[self fetchCollections];
}

- (void) uploadDidUpdateNotification:(NSNotification *)notification
{
	[self refreshUploadsForCurrentFilter];
}

- (IBAction) search:(id)sender
{
	self.currentSearch = [self currentSearchFieldString];
	[self refreshUploadsForCurrentFilter];
}

- (void) controlTextDidChange:(NSNotification *)notification
{
	if (notification.object == self.searchField && [self currentSearchFieldString].length == 0) {
		self.currentSearch = @"";
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

	MBUploadProgress* uploader = [[MBUploadProgress alloc] init];
	self.uploader = uploader;

	NSString* path = url.path;
	__weak typeof(self) weakSelf = self;
	__block BOOL didCompleteUpload = NO;
	__block BOOL reportedFailure = NO;

	[uploader uploadFileInBackground:path completion:^(CGFloat percent, NSError* error) {
		__strong typeof(self) strongSelf = weakSelf;
		if (!strongSelf) {
			return;
		}

		if (uploader.cancelRequested) {
			return;
		}

		if (error && !reportedFailure) {
			reportedFailure = YES;
			[strongSelf restoreProgressSpinnerAfterVideoUpload];
			strongSelf.uploader = nil;
			NSString* message = [error mb_networkMessageWithResponse:nil];
			[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:message button:@"OK" completionHandler:NULL];
			if (handler && !uploader.cancelRequested) {
				handler();
			}
			return;
		}

		if (uploader.cancelRequested) {
			return;
		}

		strongSelf.progressSpinner.doubleValue = percent;

		if (!didCompleteUpload && percent >= 1.0) {
			if (uploader.cancelRequested) {
				return;
			}

			didCompleteUpload = YES;
			[uploader uploadFinished:^(BOOL success) {
				__strong typeof(self) innerSelf = weakSelf;
				if (!innerSelf) {
					return;
				}

				if (uploader.cancelRequested) {
					return;
				}

				if (!success) {
					[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"The video upload failed. Please try again." button:@"OK" completionHandler:NULL];
				}
				else {
					[innerSelf refreshUploadsForCurrentFilter];
				}

				[innerSelf restoreProgressSpinnerAfterVideoUpload];
				innerSelf.uploader = nil;

				if (handler && !uploader.cancelRequested) {
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
	self.progressCancelButton.hidden = NO;
	self.blogNameButton.hidden = YES;
}

- (void) restoreProgressSpinnerAfterVideoUpload
{
	self.progressSpinner.doubleValue = 0.0;
	self.progressSpinner.indeterminate = YES;
	self.progressSpinner.style = NSProgressIndicatorStyleSpinning;
	self.progressSpinner.displayedWhenStopped = NO;
	[self.progressSpinner stopAnimation:nil];
	self.progressCancelButton.hidden = YES;
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
			RFDispatchThread(^{
				@autoreleasepool {
					NSImage* img = [[NSImage alloc] initWithContentsOfFile:filepath];
					NSImage* scaled_img;
					if ([RFSettings isPremium]) {
						scaled_img = [img rf_scaleToSmallestDimension:3000];
					}
					else {
						scaled_img = [img rf_scaleToSmallestDimension:1800];
					}

					if (scaled_img == nil) {
						RFDispatchMainAsync(^{
							[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"The photo file could not be read." button:@"OK" completionHandler:NULL];
							[self hideUploadProgress];
						});
						return;
					}

					RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];
					NSString* filename = [filepath lastPathComponent];
					[self uploadPhoto:photo filename:filename completion:^{
						[self finishUpload:filepath];
						[self uploadNextPhoto:paths];
					}];
				}
			});
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
		[self refreshUploadsForCurrentFilter];
	}
}

- (void) uploadPhoto:(RFPhoto *)photo filename:(NSString *)filename completion:(void (^)(void))handler
{
	NSData* d = [photo jpegData];
	if (d == nil) {
		RFDispatchMainAsync(^{
			[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"The photo file could not be prepared for upload." button:@"OK" completionHandler:NULL];
			[self hideUploadProgress];
		});
		return;
	}

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
	[client uploadImageData:d named:@"file" filename:filename httpMethod:@"POST" queryArguments:args isVideo:is_video isGIF:is_gif isPNG:is_png completion:^(UUHttpResponse* response) {
		NSDictionary* headers = response.httpResponse.allHeaderFields;
		NSString* image_url = headers[@"Location"];
		RFDispatchMainAsync (^{
			if (![self responseWasSuccessful:response]) {
				NSString* message = [self errorMessageForResponse:response fallback:@"The photo could not be uploaded."];
				[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:message button:@"OK" completionHandler:NULL];
				[self hideUploadProgress];
			}
			else if (image_url == nil) {
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
	RFDispatchThread(^{
		@autoreleasepool {
			NSData* d = [NSData dataWithContentsOfFile:path];
			if (d == nil) {
				RFDispatchMainAsync(^{
					[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:@"The file could not be read." button:@"OK" completionHandler:NULL];
					[self hideUploadProgress];
				});
				return;
			}

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
					if (![self responseWasSuccessful:response]) {
						NSString* message = [self errorMessageForResponse:response fallback:@"The file could not be uploaded."];
						[NSAlert rf_showOneButtonAlert:@"Error Uploading File" message:message button:@"OK" completionHandler:NULL];
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
	});
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
	if (index_path == nil || index_path.item >= self.allPosts.count) {
		return;
	}

	RFUpload* up = [self.allPosts objectAtIndex:index_path.item];
	if (up.url.length == 0) {
		return;
	}

	if ([up isPhoto]) {
		NSMutableDictionary* info = [NSMutableDictionary dictionary];
		[info setObject:[NSURL URLWithString:up.url] forKey:kOpenPhotoURLKey];
		if (up.alt) {
			[info setObject:up.alt forKey:kOpenPhotoAltKey];
		}
		[info setObject:@(YES) forKey:kOpenPhotoAllowCopyKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:kOpenPhotoURLNotification object:self userInfo:info];
	}
	else {
		NSDictionary* info = @{
			kOpenVideoURLKey: [NSURL URLWithString:up.url]
		};
		[[NSNotificationCenter defaultCenter] postNotificationName:kOpenVideoURLNotification object:self userInfo:info];
	}
}

- (void) delete:(id)sender
{
	NSSet* index_paths = [self.collectionView selectionIndexPaths];
	NSIndexPath* index_path = [index_paths anyObject];
	if (index_path && index_path.item < self.allPosts.count) {
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

			if (![self responseWasSuccessful:response]) {
				NSString* message = [self errorMessageForResponse:response fallback:@"The upload could not be deleted."];
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Upload" message:message button:@"OK" completionHandler:NULL];
			}
			else if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
				NSString* msg = response.parsedResponse[@"error_description"];
				if (msg.length == 0) {
					msg = @"The upload could not be deleted.";
				}
				[NSAlert rf_showOneButtonAlert:@"Error Deleting Upload" message:msg button:@"OK" completionHandler:NULL];
			}
			else {
				[self refreshUploadsForCurrentFilter];
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
		self.currentSearch = @"";
		self.searchField.enabled = YES;
		self.searchField.stringValue = @"";
		
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
			[self refreshUploadsForCurrentFilter];
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

- (void) reloadUpload:(RFUpload *)upload atIndexPathIfCurrent:(NSIndexPath *)indexPath
{
	if (indexPath.item >= self.allPosts.count) {
		return;
	}

	RFUpload* current_upload = [self.allPosts objectAtIndex:indexPath.item];
	if (current_upload != upload) {
		return;
	}

	[self.collectionView mb_safeReloadAtIndexPath:indexPath];
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	NSUserInterfaceItemIdentifier identifier = self.photoCellIdentifier ?: kPhotoCellIdentifier;
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:identifier forIndexPath:indexPath];
	item.view.wantsLayer = YES;
	item.view.layer.cornerRadius = kUploadCellCornerRadius;
	item.view.layer.masksToBounds = YES;
	if (indexPath.item >= self.allPosts.count) {
		item.url = nil;
		item.poster_url = nil;
		item.alt = nil;
		item.isAI = NO;
		item.width = 0;
		item.height = 0;
		item.thumbnailImageView.image = nil;
		item.iconView.hidden = YES;
		return item;
	}

	RFUpload* up = [self.allPosts objectAtIndex:indexPath.item];
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
	item.width = up.width;
	item.height = up.height;
	[item setupForURL];
	[item setupForCollection:self.selectedCollection];
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(RFPhotoCell *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.item >= self.allPosts.count) {
		return;
	}

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
						[self reloadUpload:up atIndexPathIfCurrent:indexPath];
					});
				}
				else {
					// if thumbnail fails (not on CDN yet), fall back to blog URL
					[UUHttpSession get:up.url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
						if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
							NSImage* img = response.parsedResponse;
							RFDispatchMain(^{
								up.cachedImage = img;
								[self reloadUpload:up atIndexPathIfCurrent:indexPath];
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
						[self reloadUpload:up atIndexPathIfCurrent:indexPath];
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
		if (item == nil) {
			continue;
		}

		item.selectionOverlayView.layer.opacity = 0.4;
		item.selectionOverlayView.layer.backgroundColor = [NSColor blackColor].CGColor;
	}
	
	// also notify get info window
	NSIndexPath* index_path = [indexPaths anyObject];
	if (index_path == nil || index_path.item >= self.allPosts.count) {
		return;
	}

	RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
	RFUpload* upload = [self.allPosts objectAtIndex:index_path.item];
	NSString* url = item.url ?: upload.url;
	if (url.length == 0) {
		return;
	}

	NSString* alt = item.alt ?: upload.alt;
	if (alt == nil) {
		alt = @"";
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:kUpdateInfoNotification object:self userInfo:@{
		kInfoURLKey: url,
		kInfoTextKey: alt,
		kInfoAIKey: @(upload.isAI)
	}];
}

- (void) collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		if (item == nil) {
			continue;
		}

		item.selectionOverlayView.layer.opacity = 0.0;
		item.selectionOverlayView.layer.backgroundColor = nil;
	}
}

#pragma mark -

- (id<NSPasteboardWriting>) collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.item >= self.allPosts.count) {
		return nil;
	}

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
