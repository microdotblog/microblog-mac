//
//  RFPostController.m
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPostController.h"

#import "RFConstants.h"
#import "RFMacros.h"
#import "RFClient.h"
#import "RFPhoto.h"
#import "RFPhotoCell.h"
#import "RFCategoryCell.h"
#import "MBCrosspostCell.h"
#import "RFBlogsController.h"
#import "RFPhotoAltController.h"
#import "RFMicropub.h"
#import "RFPost.h"
#import "RFSettings.h"
#import "RFAccount.h"
#import "RFHighlightingTextStorage.h"
#import "MBPostWindow.h"
#import "UUString.h"
#import "UUDate.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "SAMKeychain.h"
#import "NSAlert+Extras.h"
#import "NSImage+Extras.h"
#import "NSString+Extras.h"
#import "NSCollectionView+Extras.h"
#import "NSAppearance+Extras.h"
#import "MMMarkdown.h"
#import "RFAutoCompleteCache.h"
#import "RFUserCache.h"
#import "MBSelectiveUsernamesController.h"
#import "MBDateController.h"
#import "SDAVAssetExportSession.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kPhotoCellIdentifier = @"PhotoCell";
static NSString* const kCategoryCellIdentifier = @"CategoryCell";
static NSString* const kCrosspostCellIdentifier = @"CrosspostCell";
static CGFloat const kTextViewTitleHiddenTop = 14;
static CGFloat const kTextViewTitleShownTop = 54;

@interface RFPostController()

@property (strong, nonatomic) NSString* activeReplacementString;
@property (strong, atomic) NSMutableArray* autoCompleteData;
@property (assign, nonatomic) BOOL resettingAutoComplete;

@end

@implementation RFPostController

- (id) init
{
	self = [super initWithNibName:@"Post" bundle:nil];
	if (self) {
		self.attachedPhotos = @[];
		self.queuedPhotos = @[];
		self.categories = @[];
		self.crosspostServices = @[];
		self.selectedCategories = @[];
		self.selectedCrosspostUIDs = @[];
		self.channel = @"default";
	}
	
	return self;
}

- (id) initWithPost:(RFPost *)post
{
	self = [self init];
	if (self) {
		self.editingPost = post;
		self.initialText = post.text;
		self.isReply = post.isReply;
		if (post.isReply) {
			self.isShowingTitle = NO;
		}
		else {
			self.isShowingTitle = YES;
		}
		self.channel = self.editingPost.channel;
		self.selectedCategories = self.editingPost.categories;
		self.selectedCrosspostUIDs = self.editingPost.syndication;
	}
	
	return self;
}

- (id) initWithChannel:(NSString *)channel
{
	self = [self init];
	if (self) {
		self.channel = channel;
		self.isShowingTitle = YES;
	}
	
	return self;
}

- (id) initWithText:(NSString *)text
{
	self = [self init];
	if (self) {
		self.initialText = text;
	}
	
	return self;
}

- (id) initWithPhoto:(RFPhoto *)photo
{
	self = [self init];
	if (self) {
		self.attachedPhotos = @[ photo ];
	}
	
	return self;
}

- (id) initWithPostID:(NSString *)postID username:(NSString *)username
{
	self = [self init];
	if (self) {
		self.isReply = YES;
		self.replyPostID = postID;
		self.replyUsername = username;
	}
	
	return self;
}

- (void) dealloc
{
	for (RFPhoto* photo in self.attachedPhotos) {
		[photo removeTemporaryVideo];
	}
}

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self restoreDraft];

	[self setupTitle];
	[self setupText];
	[self setupCollectionView];
	[self setupSummary];
	[self setupBlogName];
	[self setupButtons];
	[self setupUsernames];
	[self setupNotifications];

	[self updateTitleHeaderWithAnimation:NO];
	[self downloadCategories];
	[self downloadBlogs];
}

- (void) viewDidAppear
{
	[super viewDidAppear];
}

- (void) viewDidLayout
{
	[super viewDidLayout];
}

- (void) setupTitle
{
	if (self.editingPost) {
		self.titleField.stringValue = self.editingPost.title;
	}
}

- (void) setupText
{
	self.textStorage = [[RFHighlightingTextStorage alloc] init];
	[self.textStorage addLayoutManager:self.textView.layoutManager];

	self.textUndoManager = [[NSUndoManager alloc] init];
	
	if (self.replyUsername) {
		self.textView.string = [NSString stringWithFormat:@"@%@ ", self.replyUsername];
	}
	else if (self.initialText) {
		self.textView.string = self.initialText;
	}

	NSFont* normal_font = [NSFont systemFontOfSize:kDefaultFontSize];
	self.textView.typingAttributes = @{
		NSFontAttributeName: normal_font
	};
	
	self.textView.delegate = self;
	self.textView.textStorage.delegate = self;
	self.textView.automaticQuoteSubstitutionEnabled = NO;
	self.textView.automaticDashSubstitutionEnabled = NO;
	
	[self updateRemainingChars];
	
	if (self.isReply || self.editingPost || [self isPage]) {
		self.photoButton.hidden = YES;
	}
}

- (void) setupBlogName
{
	if (self.isReply) {
		self.blognameField.hidden = YES;
	}
	else {
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
			if (s) {
				self.blognameField.stringValue = s;
			}
			else {
				self.blognameField.stringValue = [RFSettings stringForKey:kAccountDefaultSite];
			}
		}
		else if ([self hasMicropubBlog]) {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalMicropubMe];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.blognameField.stringValue = endpoint_url.host;
		}
		else {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalBlogEndpoint];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.blognameField.stringValue = endpoint_url.host;
		}

		NSGestureRecognizer* click = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(blogNameClicked:)];
		[self.blognameField addGestureRecognizer:click];
	}
}

- (void) setupButtons
{
	NSImage* img = [NSImage rf_imageWithSystemSymbolName:@"photo" accessibilityDescription:@"photo"];
	self.photoButton.image = img;
	
	if ([NSAppearance mb_isLiquidGlass]) {
		// add more padding because rounded corners
		self.photoButtonLeftConstraint.constant = 14;
		self.characterCountRightConstraint.constant = 14;
	}
}

- (void) setupUsernames
{
//	self.usernamesController = [[MBSelectiveUsernamesController alloc] initWithCollectionView:self.usernamesCollectionView];
}

- (void) setupCollectionView
{
	self.photosCollectionView.delegate = self;
	self.photosCollectionView.dataSource = self;
	
	[self.photosCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"PhotoCell" bundle:nil] forItemWithIdentifier:kPhotoCellIdentifier];

	if (self.attachedPhotos.count > 0) {
		self.photosHeightConstraint.constant = 100;
	}
	else {
		self.photosHeightConstraint.constant = 0;
	}

	[self.categoriesCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"CategoryCell" bundle:nil] forItemWithIdentifier:kCategoryCellIdentifier];
	[self.categoriesCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"CrosspostCell" bundle:nil] forItemWithIdentifier:kCrosspostCellIdentifier];
	self.categoriesHeightConstraint.constant = 0;
}

- (void) setupSummary
{
	self.summaryTextView.font = [NSFont systemFontOfSize:14];
	self.summaryHeightConstraint.constant = 0;
	self.summaryBackgroundView.hidden = YES;
	
	if (self.editingPost && self.editingPost.summary) {
		self.summaryTextView.string = self.editingPost.summary;
		[self summaryTextDidChange:nil];
	}
}

- (void) setupDragging
{
	NSMutableArray* types = [[NSFilePromiseReceiver readableDraggedTypes] mutableCopy];
	[types addObject:NSPasteboardTypeFileURL];
	[self.textView registerForDraggedTypes:types];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachFilesNotification:) name:kAttachFilesNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAttachedPhotoNotification:) name:kRemoveAttachedPhotoNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAutoCompleteNotification:) name:kFoundUserAutoCompleteNotification object:self.textView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetAutoCompleteNotification:) name:kResetUserAutoCompleteNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postingCheckboxChangedNotification:) name:kPostingCheckboxChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(summaryTextDidChange:) name:NSTextDidChangeNotification object:self.summaryTextView];
}

#pragma mark -

- (void) restoreDraft
{
	// only restore draft if there aren't other post windows open already
	if ([self countPostWindows] == 0) {
		NSString* path = [RFAccount autosaveDraftFileForChannel:self.channel];
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) {
			self.initialText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

- (NSInteger) countPostWindows
{
	NSInteger num_windows = 0;
	
	NSArray* windows = CFBridgingRelease (CGWindowListCopyWindowInfo (kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
	for (NSDictionary* info in windows) {
		NSNumber* num = [info objectForKey:(NSString *)kCGWindowNumber];
		NSWindow* win = [[NSApplication sharedApplication] windowWithWindowNumber:num.integerValue];
		if (win) {
			if ([win isKindOfClass:[MBPostWindow class]]) {
				num_windows++;
			}
		}
	}
		
	return num_windows;
}

- (BOOL) isPage
{
	return [self.channel isEqualToString:@"pages"];
}

- (void) blogNameClicked:(NSGestureRecognizer *)gesture
{
	[self showBlogsMenu];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(toggleTitleField:)) {
		if ([self isPage]) {
			[item setState:NSControlStateValueOn];
			return NO;
		}
		else if (self.isReply) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isShowingTitle) {
			[item setState:NSControlStateValueOn];
			return YES;
		}
		else {
			[item setState:NSControlStateValueOff];
			return YES;
		}
	}
	else if (item.action == @selector(toggleCategories:)) {
		if ([self isPage]) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isReply) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isShowingCategories) {
			[item setState:NSControlStateValueOn];
			return YES;
		}
		else {
			[item setState:NSControlStateValueOff];
			return YES;
		}
	}
	else if (item.action == @selector(toggleCrossposting:)) {
		if ([self isPage]) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isReply) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isShowingCrosspostServices) {
			[item setState:NSControlStateValueOn];
			return YES;
		}
		else {
			[item setState:NSControlStateValueOff];
			return YES;
		}
	}
	else if (item.action == @selector(toggleSummary:)) {
		if ([self isPage]) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isReply) {
			[item setState:NSControlStateValueOff];
			return NO;
		}
		else if (self.isShowingSummary) {
			[item setState:NSControlStateValueOn];
			return YES;
		}
		else {
			[item setState:NSControlStateValueOff];
			return YES;
		}
	}
	else if (item.action == @selector(save:)) {
		if ([self isPage]) {
			return NO;
		}
		else if ([self isReply]) {
			return NO;
		}
		else {
			return ([RFSettings hasSnippetsBlog] && ![RFSettings prefersExternalBlog]);
		}
	}
	else if (item.action == @selector(schedulePost:)) {
		if (![RFSettings hasSnippetsBlog] || [RFSettings prefersExternalBlog]) {
			return NO;
		}
		else if ([self isPage]) {
			return NO;
		}
		else if ([self isReply]) {
			return NO;
		}
		else if (self.editingPost && !self.editingPost.isDraft) {
			return NO;
		}
		else {
			return YES;
		}
	}
	else {
		return YES;
	}
}

- (void) updateTitleHeader
{
	[self updateTitleHeaderWithAnimation:YES];
}

- (void) updateTitleHeaderWithAnimation:(BOOL)animate
{
	if (self.isShowingTitle) {
		self.titleField.hidden = NO;
		self.titleSeparatorLine.hidden = NO;

		if (animate) {
			self.titleField.animator.alphaValue = 1.0;
			self.titleSeparatorLine.animator.alphaValue = 1.0;
			self.textTopConstraint.animator.constant = kTextViewTitleShownTop;
		}
		else {
			self.titleField.alphaValue = 1.0;
			self.textTopConstraint.constant = kTextViewTitleShownTop;
		}
	}
	else {
		if (animate) {
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
				self.titleField.animator.alphaValue = 0.0;
				self.textTopConstraint.animator.constant = kTextViewTitleHiddenTop;
			} completionHandler:^{
				self.titleField.hidden = YES;
				self.titleSeparatorLine.hidden = YES;
				self.titleField.stringValue = @"";
			}];
		}
		else {
			self.titleField.alphaValue = 0.0;
			self.textTopConstraint.constant = kTextViewTitleHiddenTop;
			self.titleField.hidden = YES;
			self.titleSeparatorLine.hidden = YES;
			self.titleField.stringValue = @"";
		}
	}
}

- (void) updateCategoriesPane
{
	if (self.isShowingCategories) {
		NSInteger estimated_rows = ceil (self.categories.count / [self bestCheckboxColumnsCount]);
		if (estimated_rows == 0) {
			estimated_rows = 1;
		}
		self.categoriesHeightConstraint.animator.constant = estimated_rows * 30.0;
	}
	else if (self.isShowingCrosspostServices) {
		NSInteger estimated_rows = ceil (self.crosspostServices.count / [self bestCheckboxColumnsCount]);
		if (estimated_rows == 0) {
			estimated_rows = 1;
		}
		self.categoriesHeightConstraint.animator.constant = estimated_rows * 30.0;
	}
	else {
		self.categoriesHeightConstraint.animator.constant = 0;
	}
}

- (void) updateSummaryPane
{
	if (self.isShowingSummary) {
		self.generateSummaryButton.alphaValue = 0;
		self.summaryBackgroundView.hidden = NO;
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
			self.summaryHeightConstraint.constant = 75;
		} completionHandler:^{
			self.generateSummaryButton.animator.alphaValue = 1;
			[self.view.window makeFirstResponder:self.summaryTextView];
		}];
	}
	else {
		self.summaryHeightConstraint.animator.constant = 0;
		self.summaryBackgroundView.hidden = YES;
		[self.view.window makeFirstResponder:self.textView];
	}
	
	[self summaryTextDidChange:nil];
}

- (void) updateEditedState
{
	self.view.window.documentEdited = YES;
}

- (void) updateGenerateEnabled
{
	self.generateSummaryButton.enabled = [[self currentText] length] > 0;
}

- (NSString *) postButtonTitle
{
	if (self.editingPost && self.editingPost.isDraft) {
		return @"Post";
	}
	else if (self.editingPost) {
		return @"Update";
	}
	else if ([self.channel isEqualToString:@"pages"]) {
		return @"Add Page";
	}
	else {
		return @"Post";
	}
}

- (void) updateSelectedCheckboxes
{
	if (self.isShowingCategories) {
		self.selectedCategories = [self currentSelectedCategories];
	}
	else if (self.isShowingCrosspostServices) {
		self.selectedCrosspostUIDs = [self currentSelectedCrossposting];
	}
}

- (NSInteger) bestCheckboxColumnsCount
{
	CGFloat w = self.categoriesCollectionView.bounds.size.width;
	if (w > 600.0) {
		return 4;
	}
	else if (w > 400.0) {
		return 3;
	}
	else {
		return 2;
	}
}

#pragma mark -

- (NSUndoManager *) undoManagerForTextView:(NSTextView *)textView
{
	return self.textUndoManager;
}

- (void) closeWithoutSaving
{
	self.isSent = YES;
	self.isSending = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:kClosePostingNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:kCheckTimelineNotification object:self];

	[self closeWindow];
}

- (void) finishClose
{
	if (!self.isReply && !self.isSent && !self.editingPost) {
//		NSString* title = [self currentTitle];
//		NSString* draft = [self currentText];
	}
}

- (void) closeWindow
{
	[self.view.window performClose:nil];
}

- (IBAction) toggleTitleField:(id)sender
{
	self.isShowingTitle = !self.isShowingTitle;
	if (self.isShowingTitle) {
		[self.textView.window makeFirstResponder:self.titleField];
	}
	else {
		[self.textView.window makeFirstResponder:self.textView];
	}
	
	[self updateTitleHeader];
}

- (IBAction) toggleCategories:(id)sender
{
	[self updateSelectedCheckboxes];
	
	self.isShowingCategories = !self.isShowingCategories;
	self.isShowingCrosspostServices = NO;
	self.isShowingSummary = NO;

	[self updateCategoriesPane];
	[self updateSummaryPane];
	[self.categoriesCollectionView reloadData];
}

- (IBAction) toggleCrossposting:(id)sender
{
	[self updateSelectedCheckboxes];

	self.isShowingCrosspostServices = !self.isShowingCrosspostServices;
	self.isShowingCategories = NO;
	self.isShowingSummary = NO;

	[self updateCategoriesPane];
	[self updateSummaryPane];
	[self.categoriesCollectionView reloadData];
}

- (IBAction) toggleSummary:(id)sender
{
	[self updateSelectedCheckboxes];

	self.isShowingSummary = !self.isShowingSummary;
	self.isShowingCategories = NO;
	self.isShowingCrosspostServices = NO;

	[self updateCategoriesPane];
	[self updateSummaryPane];
	[self.categoriesCollectionView reloadData];
}

//- (IBAction) close:(id)sender
//{
//	[[NSNotificationCenter defaultCenter] postNotificationName:kClosePostingNotification object:self];
//}

- (void) attachExternalPhoto:(NSString *)url altText:(NSString *)altText
{
	RFPhoto* new_photo = [[RFPhoto alloc] init];
	new_photo.publishedURL = url;
	new_photo.altText = altText;
	
	self.attachedPhotos = @[ new_photo ];
	[self.photosCollectionView reloadData];

	self.photosHeightConstraint.animator.constant = 100;

	[self checkMediaEndpoint];
}

- (void) attachPhotos:(NSArray<NSURL*>*)photoURLs
{
	NSMutableArray* new_photos = [self.attachedPhotos mutableCopy];
	BOOL too_many_photos = NO;

	for (NSURL* file_url in photoURLs) {
		// Bail out if we've exceeded the 10-item limit per post
		if (new_photos.count >= 10) {
			too_many_photos = YES;
			break;
		}

		NSArray* video_extensions = @[ @"mov", @"m4v", @"mp4" ];
		if ([video_extensions containsObject:[[file_url pathExtension] lowercaseString]]) {
			AVURLAsset* asset = [AVURLAsset assetWithURL:file_url];
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:nil];
			photo.videoAsset = asset;
			photo.isVideo = YES;

			[self startProgressAnimation];
			[photo transcodeVideo:^(NSURL* new_url) {
				if ([self checkVideoFile:new_url]) {
					AVURLAsset* new_asset = [AVURLAsset assetWithURL:new_url];
					NSError* error = nil;
					AVAssetImageGenerator* imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:new_asset];
					CGImageRef cgImage = [imageGenerator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:&error];
					photo.videoAsset = new_asset;
					photo.thumbnailImage = [[NSImage alloc] initWithCGImage:cgImage size:CGSizeZero];
					[new_photos addObject:photo];

					self.attachedPhotos = new_photos;
					[self stopProgressAnimation];
					[self.photosCollectionView reloadData];
					
					CGImageRelease (cgImage);
				}
				else {
					[self stopProgressAnimation];
					[photo removeTemporaryVideo];
				}
			}];
		}
		else if ([[[file_url pathExtension] lowercaseString] isEqualToString:@"gif"]) {
			NSImage* img = [[NSImage alloc] initWithContentsOfURL:file_url];
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:img];
			photo.isGIF = YES;
			photo.fileURL = file_url;
			[new_photos addObject:photo];
		}
		else if ([[[file_url pathExtension] lowercaseString] isEqualToString:@"png"]) {
			NSImage* img = [[NSImage alloc] initWithContentsOfURL:file_url];
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:img];
			photo.isPNG = YES;
			photo.fileURL = file_url;
			[new_photos addObject:photo];
		}
		else {
			NSImage* img = [[NSImage alloc] initWithContentsOfURL:file_url];
			NSImage* scaled_img;
			if ([RFSettings isPremium]) {
				scaled_img = [img rf_scaleToSmallestDimension:3000];
			}
			else {
				scaled_img = [img rf_scaleToSmallestDimension:1800];
			}
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];
			[new_photos addObject:photo];
		}
	}

	self.attachedPhotos = new_photos;
	[self.photosCollectionView reloadData];

	self.photosHeightConstraint.animator.constant = 100;

	[self checkMediaEndpoint];

	if (too_many_photos) {
		[NSAlert rf_showOneButtonAlert:@"Only 10 Items Added" message:@"The first 10 items were added to your post." button:@"OK" completionHandler:NULL];
	}
}

- (IBAction) choosePhoto:(id)sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[ @"public.image", @"public.movie" ];
	panel.allowsMultipleSelection = NO;
	
	[panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			NSArray* urls = panel.URLs;
			[self attachPhotos:urls];
		}
		
		[self becomeFirstResponder];
	}];
}

- (void) textDidChange:(NSNotification *)notification
{
	[self updateRemainingChars];

	if (!self.isReply && ([self currentProcessedMarkup].length > [self maxCharsForCurrentText])) {
		if (!self.isReply) {
			self.isShowingTitle = YES;
		}
	}

	[self updateTitleHeader];
	[self updateEditedState];
	[self updateGenerateEnabled];
}

- (void) summaryTextDidChange:(NSNotification *)notification
{
	BOOL is_using_ai = [RFSettings boolForKey:kIsUsingAI];
	if (!is_using_ai) {
		// always hide Generate button if AI disabled
		self.generateSummaryButton.hidden = YES;
		self.summaryTextHeightConstraint.constant = 60;
	}
	else if (self.summaryTextView.string.length > 0) {
		self.generateSummaryButton.hidden = YES;
		self.summaryTextHeightConstraint.constant = 60;
	}
	else {
		self.generateSummaryButton.hidden = NO;
		self.summaryTextHeightConstraint.constant = 38;
		[self updateGenerateEnabled];
	}
}

- (IBAction) titleFieldDidChange:(id)sender
{
	[self updateRemainingChars];
}

- (void) attachFilesNotification:(NSNotification *)notification
{
	NSArray* paths = [notification.userInfo objectForKey:kAttachFilesPathsKey];
	NSMutableArray* urls = [NSMutableArray array];
	for (NSString* filepath in paths) {
		NSURL* url = [NSURL fileURLWithPath:filepath];
		if (url != nil) {
			[urls addObject:url];
		}
	}

	if ([urls count] > 0) {
		[self attachPhotos:urls];
	}
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self setupBlogName];
	[self hideBlogsMenu];
	[self downloadCategories];
	[self downloadBlogs];
}

- (void) removeAttachedPhotoNotification:(NSNotification *)notification
{
	NSIndexPath* index_path = [notification.userInfo objectForKey:kRemoveAttachedPhotoIndexPath];
	[self removePhotoAtIndex:index_path];
}

- (void) handleAutoCompleteNotification:(NSNotification *)notification
{
	NSDictionary* dictionary = [notification.userInfo objectForKey:kFoundUserAutoCompleteInfoKey];
	NSArray* array = dictionary[@"array"];
	self.activeReplacementString = dictionary[@"string"];

	if (!array.count)
	{
		if (self.activeReplacementString.length > 3)
		{
			NSString* cleanUserName = self.activeReplacementString;
			if ([cleanUserName uuStartsWithSubstring:@"@"])
			{
				cleanUserName = [cleanUserName substringFromIndex:1];
			}
							   
			NSString* path = [NSString stringWithFormat:@"/users/search?q=%@", cleanUserName];
			RFClient* client = [[RFClient alloc] initWithPath:path];
			[client getWithQueryArguments:nil completion:^(UUHttpResponse* response) {
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSArray class]]) {
					NSMutableArray* matchingUsernames = [NSMutableArray array];
					NSArray* array = response.parsedResponse;
					for (NSDictionary* userDictionary in array) {
						NSString* userName = userDictionary[@"username"];
						[matchingUsernames addObject:userName];
					}
										
					NSDictionary* dictionary = @{ @"string" : self.activeReplacementString, @"array" : matchingUsernames };
					dispatch_async(dispatch_get_main_queue(), ^{
						[[NSNotificationCenter defaultCenter] postNotificationName:kFoundUserAutoCompleteNotification object:self.textView userInfo:@{ kFoundUserAutoCompleteInfoKey: dictionary }];
					});
				}
			}];
		}
	}

	@synchronized(self.autoCompleteData)
	{
		[self.autoCompleteData removeAllObjects];
		self.autoCompleteData = [NSMutableArray array];
						   
		NSUInteger count = array.count;
						   
		for (NSUInteger i = 0; i < count; i++)
		{
			NSString* username = [array objectAtIndex:i];
			NSMutableDictionary* userDictionary = [NSMutableDictionary dictionaryWithDictionary:@{ 	@"username" : username } ];
				
			[self.autoCompleteData addObject:userDictionary];
		}
	}
	
	[self.textView complete:self];
}

- (void) resetAutoCompleteNotification:(NSNotification *)notification
{
	@synchronized(self.autoCompleteData) {
		// clear some data
		[self.autoCompleteData removeAllObjects];
		self.activeReplacementString = @"";
		self.resettingAutoComplete = YES;
		
		// wait a second and then allow auto-complete again
		[NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer* _Nonnull timer) {
			self.resettingAutoComplete = NO;
		}];
	}
}

- (void) postingCheckboxChangedNotification:(NSNotification *)notification
{
	[self updateSelectedCheckboxes];
}

- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(nullable NSInteger *)index
{
	if (self.resettingAutoComplete) {
		return nil;
	}
	
	if (self.autoCompleteData.count > 0) {
		NSMutableArray* array = [NSMutableArray array];
		for (NSDictionary* dictionary in self.autoCompleteData)
		{
			NSString* username = dictionary[@"username"];
			[array addObject:username];
		}
		
		return array;
	}
	
	return nil;
}

- (NSArray<NSTextCheckingResult *> *) textView:(NSTextView *)view didCheckTextInRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary<NSTextCheckingOptionKey, id> *)options results:(NSArray<NSTextCheckingResult *> *)results orthography:(NSOrthography *)orthography wordCount:(NSInteger)wordCount
{
	NSArray* okay_words = @[ @"img", @"blockquote", @"quoteback" ];
	
	NSMutableArray* new_results = [results mutableCopy];
	for (NSTextCheckingResult* result in results) {
		if (result.resultType == NSTextCheckingTypeSpelling) {
			NSString* misspelled_word = [[self currentText] substringWithRange:result.range];
			if ([okay_words containsObject:misspelled_word]) {
				[new_results removeObject:result];
			}
		}
	}
	
	return new_results;
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	if (collectionView == self.photosCollectionView) {
		return self.attachedPhotos.count;
	}
	else if (self.isShowingCrosspostServices) {
		return self.crosspostServices.count;
	}
	else {
		return self.categories.count;
	}
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	if (collectionView == self.photosCollectionView) {
		RFPhoto* photo = [self.attachedPhotos objectAtIndex:indexPath.item];
		
		RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
		[item disableMenu];

		if (photo.thumbnailImage != nil) {
			item.thumbnailImageView.image = photo.thumbnailImage;
			item.progressSpinner.hidden = NO;
		}
		else {
			item.progressSpinner.hidden = NO;
			[item.progressSpinner startAnimation:nil];
			
			// download thumbnail
			RFClient* client = [[RFClient alloc] initWithURL:photo.publishedURL];
			[client getWithCompletion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					[item.progressSpinner stopAnimation:nil];
					if (response.httpError == nil) {
						NSImage* img = [[NSImage alloc] initWithData:[response rawResponse]];
						item.thumbnailImageView.image = img;
						photo.thumbnailImage = img;
						[collectionView mb_safeReloadAtIndexPath:indexPath];
					}
				});
			}];
		}
		
		return item;
	}
	else if (self.isShowingCrosspostServices) {
		NSDictionary* info = [self.crosspostServices objectAtIndex:indexPath.item];
		NSString* service_uid = info[@"uid"];
		NSString* service_name = info[@"name"];

		MBCrosspostCell* item = (MBCrosspostCell *)[collectionView makeItemWithIdentifier:kCrosspostCellIdentifier forIndexPath:indexPath];
		item.uid = service_uid;
		item.nameCheckbox.title = service_name;
		item.nameCheckbox.state = [self.selectedCrosspostUIDs containsObject:service_uid];
		
		return item;
	}
	else {
		NSString* category_name = [self.categories objectAtIndex:indexPath.item];

		RFCategoryCell* item = (RFCategoryCell *)[collectionView makeItemWithIdentifier:kCategoryCellIdentifier forIndexPath:indexPath];
		item.categoryCheckbox.title = category_name;
		item.categoryCheckbox.state = [self.selectedCategories containsObject:category_name];
		
		return item;
	}
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	if (collectionView == self.photosCollectionView) {
		NSIndexPath* index_path = [indexPaths anyObject];
		[self performSelector:@selector(clickedPhotoAtIndex:) withObject:index_path afterDelay:0.1];
		[collectionView deselectAll:nil];
	}
}

- (NSSize) collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	NSSize cell_size;
	
	if (collectionView == self.photosCollectionView) {
		cell_size.width = 100;
		cell_size.height = 100;
	}
	else {
		cell_size.width = collectionView.bounds.size.width / [self bestCheckboxColumnsCount];
		cell_size.height = 30;
	}
	
	return cell_size;
}

#pragma mark -

- (BOOL) hasSnippetsBlog
{
	return [RFSettings boolForKey:kHasSnippetsBlog];
}

- (BOOL) hasMicropubBlog
{
	return ([RFSettings stringForKey:kExternalMicropubMe] != nil);
}

- (BOOL) prefersExternalBlog
{
	return [RFSettings boolForKey:kExternalBlogIsPreferred];
}

- (NSString *) currentTitle
{
	if (self.titleField.alphaValue > 0.0) {
		return self.titleField.stringValue;
	}
	else {
		return @"";
	}
}

- (NSString *) currentText
{
	return self.textStorage.string;
}

- (NSString *) currentProcessedMarkup
{
	NSError* error = nil;
	NSString* html = [MMMarkdown HTMLStringWithMarkdown:[self currentText] extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
	if (html.length > 0) {
		// Markdown processor adds a return at the end
		html = [html substringToIndex:html.length - 1];
		html = [html stringByReplacingOccurrencesOfString:@"</p>\n<p>" withString:@"</p>\n\n<p>"];
	}
	
	return [html rf_stripHTML];
}

- (NSString *) currentHTML
{
	NSError* error = nil;
	NSString* html = [MMMarkdown HTMLStringWithMarkdown:[self currentText] extensions:MMMarkdownExtensionsFencedCodeBlocks|MMMarkdownExtensionsTables error:&error];
	return html;
}

- (NSInteger) maxCharsForCurrentText
{
	NSString* s = [self currentHTML];
	if ([s containsString:@"<blockquote"]) {
		return kMaxCharsBlockquote;
	}
	else {
		return kMaxCharsDefault;
	}
}

- (NSString *) currentStatus
{
	if (self.isDraft) {
		return @"draft";
	}
	else {
		return @"published";
	}
}

- (NSArray *) currentSelectedCategories
{
	NSMutableArray* categories = [NSMutableArray array];
	
	if (self.isShowingCategories) {
		NSUInteger num = [self.categoriesCollectionView numberOfItemsInSection:0];
		for (NSUInteger i = 0; i < num; i++) {
			NSIndexPath* index_path = [NSIndexPath indexPathForItem:i inSection:0];
    		NSCollectionViewItem* item = [self.categoriesCollectionView itemAtIndexPath:index_path];
    		if ([item isKindOfClass:[RFCategoryCell class]]) {
				RFCategoryCell* cell = (RFCategoryCell *)item;
				if (cell.categoryCheckbox.state == NSControlStateValueOn) {
					[categories addObject:cell.categoryCheckbox.title];
				}
    		}
		}
	}
	
	return categories;
}

- (NSArray *) currentSelectedCrossposting
{
	NSMutableArray* uids = [NSMutableArray array];
	
	if (self.isShowingCrosspostServices) {
		NSUInteger num = [self.categoriesCollectionView numberOfItemsInSection:0];
		for (NSUInteger i = 0; i < num; i++) {
			NSIndexPath* index_path = [NSIndexPath indexPathForItem:i inSection:0];
			NSCollectionViewItem* item = [self.categoriesCollectionView itemAtIndexPath:index_path];
			if ([item isKindOfClass:[MBCrosspostCell class]]) {
				MBCrosspostCell* cell = (MBCrosspostCell *)item;
				if (cell.nameCheckbox.state == NSControlStateValueOn) {
					[uids addObject:cell.uid];
				}
			}
		}
	}
	
	return uids;
}

#pragma mark -

- (BOOL) checkVideoFile:(NSURL *)fileURL
{
	BOOL is_ok = YES;

	if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
		for (NSDictionary* info in self.destinations) {
			NSString* hostname = [RFSettings stringForKey:kCurrentDestinationName];
			if (hostname && [hostname isEqualToString:[info objectForKey:@"name"]]) {
				is_ok = [[info objectForKey:@"microblog-audio"] boolValue];
				if (!is_ok) {
					NSString* msg = @"Video upload requires Micro.blog Premium ($10/month). Upgrade your hosting to support podcasting and video hosting.";
					[NSAlert rf_showTwoButtonAlert:@"Upgrade Subscription" message:msg okButton:@"Learn More" cancelButton:@"Cancel" completionHandler:^(NSModalResponse returnCode) {
						if (returnCode == 1000) {
							[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://micro.blog/new/audio"]];
						}
					}];
				}
				
				break;
			}
		}
	}
	
	NSDictionary* file_info = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:NULL];
	NSNumber* file_size = [file_info objectForKey:NSFileSize];
	if ([file_size integerValue] > 75000000) { // 75 MB
		NSString* msg = @"Micro.blog is designed for short videos. File uploads should be 75 MB or less. (Usually about 4 minutes of video.)";
		[NSAlert rf_showOneButtonAlert:@"Video Can't Be Uploaded" message:msg button:@"OK" completionHandler:NULL];
		is_ok = NO;
	}

	return is_ok;
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

			NSRect r = self.blognameField.bounds;
			[self.blogsMenuPopover showRelativeToRect:r ofView:self.blognameField preferredEdge:NSRectEdgeMaxY];
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

#pragma mark -

- (IBAction) applyFormatBold:(id)sender
{
	[self replaceSelectionBySurrounding:@[ @"**", @"**" ]];
}

- (IBAction) applyFormatItalic:(id)sender
{
	[self replaceSelectionBySurrounding:@[ @"_", @"_" ]];
}

- (IBAction) applyFormatLink:(id)sender
{
	NSRange r = self.textView.selectedRange;
	if (r.length == 0) {
		[self replaceSelectionBySurrounding:@[ @"[]()" ]];
		r = self.textView.selectedRange;
		r.location = r.location - 3;
		self.textView.selectedRange = r;
	}
	else {
		[self replaceSelectionBySurrounding:@[ @"[", @"]()" ]];

		NSInteger markdown_length = [@"[]()" length];
		r.location = r.location + r.length + markdown_length - 1;
		r.length = 0;
		self.textView.selectedRange = r;
	}
}

- (void) replaceSelectionBySurrounding:(NSArray *)markup
{
	NSRange r = self.textView.selectedRange;
	if (r.length == 0) {
		[self.textView replaceCharactersInRange:r withString:[markup firstObject]];
		r.location = r.location + [markup.firstObject length];
		self.textView.selectedRange = r;
	}
	else {
		NSString* s = [[self currentText] substringWithRange:r];
		NSString* new_s = [NSString stringWithFormat:@"%@%@%@", [markup firstObject], s, [markup lastObject]];
		[self.textView replaceCharactersInRange:r withString:new_s];

		NSInteger markdown_length = [[markup componentsJoinedByString:@""] length];
		r.location = r.location + r.length + markdown_length;
		r.length = 0;
		self.textView.selectedRange = r;
	}
}

- (IBAction) sendPost:(id)sender
{
	// check if there's anything to send
	NSString* s = [self currentText];
	if ((s.length == 0) && (self.attachedPhotos.count == 0)) {
		return;
	}
	
	if (!self.isSending) {
		// post button always publishes
		self.isDraft = NO;
		self.isSending = YES;
		self.view.window.documentEdited = NO;
		[self uploadPost];
	}
}

- (IBAction) save:(id)sender
{
	// cmd-S saves to server
	self.isDraft = YES;
	self.view.window.documentEdited = NO;
	[self uploadPost];
}

- (IBAction) schedulePost:(id)sender
{
	self.dateController = [[MBDateController alloc] init];
	[self.view.window beginSheet:self.dateController.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			self.postedAt = self.dateController.date;
			self.isDraft = NO;
			self.view.window.documentEdited = NO;
			[self uploadPost];
        }
        self.dateController = nil;
	}];
}

- (IBAction) generateSummary:(id)sender
{
	[self.summaryProgress startAnimation:nil];
	
	NSString* s = [self currentText];
	
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	NSURL* url = [NSURL URLWithString:destination_uid];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/account/posts/%@/summarize", url.host];
	NSDictionary* args = @{
		@"text": s,
		@"id": @""
	};
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[self.summaryTimer invalidate];
			self.summaryTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer* timer) {
				[self checkSummary];
			}];
		});
	}];
}

- (void) checkSummary
{
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	NSURL* url = [NSURL URLWithString:destination_uid];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/account/posts/%@/summarize", url.host];
	[client getWithQueryArguments:nil completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
				NSDictionary* latest = [response.parsedResponse objectForKey:@"latest"];
				NSString* summary = [latest objectForKey:@"summary"];
				if (summary.length > 0) {
					[self.summaryTextView setString:summary];
					[self.summaryTimer invalidate];
					[self.summaryProgress stopAnimation:nil];
					[self summaryTextDidChange:nil];
				}
			}
		});
	}];
}

- (void) uploadPost
{
	// update selected categories and cross-posting if visible
	[self updateSelectedCheckboxes];
	
	// upload photos and then text
	NSString* s = [self currentText];
	if ((s.length > 0) || (self.attachedPhotos.count > 0)) {
		if (self.attachedPhotos.count > 0) {
			if (([s characterAtIndex:0] == '@') && [self hasSnippetsBlog] && ![self prefersExternalBlog]) {
				NSString* msg = @"When replying to another Micro.blog user, photos are not currently supported. Start the post with different text and @-mention the user elsewhere in the post to make this a microblog post with inline photos on your site.";
				[NSAlert rf_showOneButtonAlert:@"Replies Can't Use Photos" message:msg button:@"OK" completionHandler:NULL];
				return;
			}
			
			self.queuedPhotos = [self.attachedPhotos copy];
			[self uploadNextPhoto];
		}
		else {
			[self uploadText:s];
		}
	}
}

- (void) showProgressHeader:(NSString *)statusText
{
	[self startProgressAnimation];
}

- (void) hideProgressHeader
{
	self.isSending = NO;
	[self stopProgressAnimation];
}

- (void) startProgressAnimation
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPostStartProgressNotification object:self];
}

- (void) stopProgressAnimation
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPostStopProgressNotification object:self];
}

- (void) sendUpdatedDraftNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDraftDidUpdateNotification object:self];
}

- (void) sendUpdatedReplyNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kReplyDidUpdateNotification object:self];
}

- (void) updateRemainingChars
{
	if (!self.isReply && [self currentTitle].length > 0) {
		self.remainingField.hidden = YES;
	}
	else if ([self isPage]) {
		self.remainingField.hidden = YES;
	}
	else {
		self.remainingField.hidden = NO;
	}

	NSInteger max_chars = [self maxCharsForCurrentText];
	NSInteger num_chars = [self currentProcessedMarkup].length;
	NSInteger num_remaining = max_chars - num_chars;

	NSString* s = [NSString stringWithFormat:@"%ld/%ld", (long)num_chars, (long)max_chars];
	NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:s];
	NSUInteger num_len = [[s componentsSeparatedByString:@"/"] firstObject].length;

	NSMutableParagraphStyle* para = [[NSMutableParagraphStyle alloc] init];
	para.alignment = NSTextAlignmentRight;
	[attr addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange (0, s.length)];

	if (num_remaining < 0) {
		[attr addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:1.0 green:0.3764 blue:0.3411 alpha:1.0] range:NSMakeRange (0, num_len)];
		self.remainingField.attributedStringValue = attr;
	}
	else {
		[attr addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:NSMakeRange (0, num_len)];
	}

	self.remainingField.attributedStringValue = attr;
}

- (void) uploadText:(NSString *)text
{
	if (self.isReply) {
		[self showProgressHeader:@"Now sending your reply..."];
		if (self.editingPost.postID == nil) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/posts/reply"];
			NSDictionary* args = @{
				@"id": self.replyPostID,
				@"text": text
			};
			[client postWithParams:args completion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
						[self hideProgressHeader];
						NSString* msg = response.parsedResponse[@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Reply" message:msg button:@"OK" completionHandler:NULL];
					}
					else if (response.httpError) {
						[self hideProgressHeader];
						NSString* msg = [response.httpError localizedDescription];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Reply" message:msg button:@"OK" completionHandler:NULL];
					}
					else {
						[self sendUpdatedReplyNotification];
						[self closeWithoutSaving];
					}
				});
			}];
		}
		else {
			RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
			NSDictionary* info = @{
				@"action": @"update",
				@"url": self.editingPost.url,
				@"replace": @{
					@"content": text
				}
			};
			
			[client postWithObject:info completion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
						[self hideProgressHeader];
						NSString* msg = response.parsedResponse[@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Reply" message:msg button:@"OK" completionHandler:NULL];
					}
					else if (response.httpError) {
						[self hideProgressHeader];
						NSString* msg = [response.httpError localizedDescription];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Reply" message:msg button:@"OK" completionHandler:NULL];
					}
					else {
						[self sendUpdatedReplyNotification];
						[self closeWithoutSaving];
					}
				});
			}];
		}
	}
	else {
		NSString* summary = self.summaryTextView.string;
		
		[self showProgressHeader:@"Now publishing to your microblog..."];
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
			NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
			if (destination_uid == nil) {
				destination_uid = @"";
			}
			NSArray* category_names = self.selectedCategories;
			NSArray* crosspost_uids = self.selectedCrosspostUIDs;
			
			// if everything unselected, we need to send some value so the server knows not to run all services
			if (crosspost_uids.count == 0) {
				crosspost_uids = @[ @"" ];
			}
			
			NSMutableArray* photo_urls = [NSMutableArray array];
			NSMutableArray* photo_alts = [NSMutableArray array];
			NSMutableArray* video_urls = [NSMutableArray array];
			NSMutableArray* video_alts = [NSMutableArray array];

			for (RFPhoto* photo in self.attachedPhotos) {
				if (photo.isVideo) {
					[video_urls addObject:photo.publishedURL];
					[video_alts addObject:photo.altText];
				}
				else {
					[photo_urls addObject:photo.publishedURL];
					[photo_alts addObject:photo.altText];
				}
			}

			if (self.editingPost) {
				NSDictionary* info = @{
					@"action": @"update",
					@"url": self.editingPost.url,
					@"mp-destination": destination_uid,
					@"mp-syndicate-to": crosspost_uids,
					@"replace": @{
						@"name": [self currentTitle],
						@"content": text,
						@"summary": summary,
						@"category": category_names,
						@"post-status": [self currentStatus]
					}
				};

				if (self.postedAt) {
					NSMutableDictionary* new_info = [info mutableCopy];
					NSMutableDictionary* new_replace = [[info objectForKey:@"replace"] mutableCopy];
					[new_replace setObject:[self.postedAt uuRfc3339StringForUTCTimeZone] forKey:@"published"];
					[new_info setObject:new_replace forKey:@"replace"];
					info = new_info;
				}
				
				[client postWithObject:info completion:^(UUHttpResponse* response) {
					RFDispatchMainAsync (^{
						if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
							[self hideProgressHeader];
							NSString* msg = response.parsedResponse[@"error_description"];
							[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
						}
						else if (response.httpError) {
							[self hideProgressHeader];
							NSString* msg = [response.httpError localizedDescription];
							[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
						}
						else if (!self.isDraft) {
							[self closeWithoutSaving];
						}
						else {
							[self stopProgressAnimation];
							[self sendUpdatedDraftNotification];
						}
					});
				}];
			}
			else {
				NSDictionary* args = @{
					@"name": [self currentTitle],
					@"content": text,
					@"summary": summary,
					@"photo[]": photo_urls,
					@"mp-photo-alt[]": photo_alts,
					@"video[]": video_urls,
					@"mp-video-alt[]": video_alts,
					@"mp-destination": destination_uid,
					@"mp-channel": self.channel,
					@"category[]": category_names,
					@"mp-syndicate-to[]": crosspost_uids,
					@"post-status": [self currentStatus]
				};

				if (self.postedAt) {
					NSMutableDictionary* new_args = [args mutableCopy];
					[new_args setObject:[self.postedAt uuRfc3339StringForUTCTimeZone] forKey:@"published"];
					args = new_args;
				}

				[client postWithParams:args completion:^(UUHttpResponse* response) {
					RFDispatchMainAsync (^{
						if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
							[self hideProgressHeader];
							NSString* msg = response.parsedResponse[@"error_description"];
							[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
						}
						else if (response.httpError) {
							[self hideProgressHeader];
							NSString* msg = [response.httpError localizedDescription];
							[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
						}
						else if (!self.isDraft) {
							[self closeWithoutSaving];
						}
						else {
							self.editingPost = [[RFPost alloc] init];
							self.editingPost.url = response.parsedResponse[@"url"];
							self.editingPost.isDraft = YES;
							[self stopProgressAnimation];
							[self sendUpdatedDraftNotification];
						}
					});
				}];
			}
		}
		else if ([self hasMicropubBlog]) {
			NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubPostingEndpoint];
			RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
			NSDictionary* args;
			if ([self.attachedPhotos count] > 0) {
				NSMutableArray* photo_urls = [NSMutableArray array];
				NSMutableArray* photo_alts = [NSMutableArray array];
				NSMutableArray* video_urls = [NSMutableArray array];
				NSMutableArray* video_alts = [NSMutableArray array];

				for (RFPhoto* photo in self.attachedPhotos) {
					if (photo.isVideo) {
						[video_urls addObject:photo.publishedURL];
						[video_alts addObject:photo.altText];
					}
					else {
						[photo_urls addObject:photo.publishedURL];
						[photo_alts addObject:photo.altText];
					}
				}

				args = @{
					@"h": @"entry",
					@"name": [self currentTitle],
					@"content": text,
					@"summary": summary,
					@"photo[]": photo_urls,
					@"mp-photo-alt[]": photo_alts,
					@"video[]": video_urls,
					@"mp-video-alt[]": video_alts,
					@"post-status": [self currentStatus]
				};
			}
			else {
				args = @{
					@"h": @"entry",
					@"name": [self currentTitle],
					@"content": text,
					@"post-status": [self currentStatus]
				};
			}
			
			[client postWithParams:args completion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
						[self hideProgressHeader];
						NSString* msg = response.parsedResponse[@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
					}
					else if (response.httpError) {
						[self hideProgressHeader];
						NSString* msg = [response.httpError localizedDescription];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
					}
					else if (!self.isDraft) {
						[self closeWithoutSaving];
					}
					else {
						[self stopProgressAnimation];
					}
				});
			}];
		}
		else {
			NSString* xmlrpc_endpoint = [RFSettings stringForKey:kExternalBlogEndpoint];
			NSString* blog_s = [RFSettings stringForKey:kExternalBlogID];
			NSString* username = [RFSettings stringForKey:kExternalBlogUsername];
			NSString* password = [SAMKeychain passwordForService:@"ExternalBlog" account:username];
			
			NSString* post_text = text;
			NSString* app_key = @"";
			NSNumber* blog_id = [NSNumber numberWithInteger:[blog_s integerValue]];
			RFBoolean* publish = [[RFBoolean alloc] initWithBool:YES];

			NSString* post_format = [RFSettings stringForKey:kExternalBlogFormat];
			NSString* post_category = [RFSettings stringForKey:kExternalBlogCategory];

			NSArray* params;
			NSString* method_name;

			if ([[RFSettings stringForKey:kExternalBlogApp] isEqualToString:@"WordPress"]) {
				NSMutableDictionary* content = [NSMutableDictionary dictionary];
				
				content[@"post_status"] = @"publish";
				content[@"post_title"] = [self currentTitle];
				content[@"post_content"] = post_text;
				if (post_format.length > 0) {
					if ([self currentTitle].length > 0) {
						content[@"post_format"] = @"Standard";
					}
					else {
						content[@"post_format"] = post_format;
					}
				}
				if (post_category.length > 0) {
					content[@"terms"] = @{
						@"category": @[ post_category ]
					};
				}

				params = @[ blog_id, username, password, content ];
				method_name = @"wp.newPost";
			}
			else {
				params = @[ app_key, blog_id, username, password, post_text, publish ];
				method_name = @"blogger.newPost";
			}
			
			RFXMLRPCRequest* request = [[RFXMLRPCRequest alloc] initWithURL:xmlrpc_endpoint];
			[request sendMethod:method_name params:params completion:^(UUHttpResponse* response) {
				RFXMLRPCParser* xmlrpc = [RFXMLRPCParser parsedResponseFromData:response.rawResponse];
				RFDispatchMainAsync ((^{
					if (xmlrpc.responseFault) {
						NSString* s = [NSString stringWithFormat:@"%@ (error: %@)", xmlrpc.responseFault[@"faultString"], xmlrpc.responseFault[@"faultCode"]];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:s button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
						self.photoButton.hidden = NO;
					}
					else if (response.httpError) {
						[self hideProgressHeader];
						NSString* msg = [response.httpError localizedDescription];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
					}
					else if (!self.isDraft) {
						[self closeWithoutSaving];
					}
					else {
						[self stopProgressAnimation];
					}
				}));
			}];
		}
	}
}

- (void) uploadNextPhoto
{
	RFPhoto* photo = [self.queuedPhotos firstObject];
	if (photo) {
		NSMutableArray* new_photos = [self.queuedPhotos mutableCopy];
		[new_photos removeObjectAtIndex:0];
		self.queuedPhotos = new_photos;
		
		// we only need to upload if no URL already
		if (photo.publishedURL.length == 0) {
			[self uploadPhoto:photo completion:^{
				[self uploadNextPhoto];
			}];
		}
		else {
			[self uploadNextPhoto];
		}
	}
	else {
		NSString* s = [self currentText];
		
		if ([self prefersExternalBlog] && ![self hasMicropubBlog]) {
			if (s.length > 0) {
				s = [s stringByAppendingString:@"\n\n"];
			}

			for (RFPhoto* photo in self.attachedPhotos) {
				CGSize original_size = photo.thumbnailImage.size;
				CGFloat width = 0;
				CGFloat height = 0;

				if (original_size.width > original_size.height) {
					if (original_size.width > 600.0) {
						width = 600.0;
					}
					else {
						width = original_size.width;
					}
					height = width / original_size.width * original_size.height;
				}
				else {
					if (original_size.height > 600.0) {
						height = 600.0;
					}
					else {
						height = original_size.height;
					}
					width = height / original_size.height * original_size.width;
				}

				if (photo.isVideo) {
					s = [s stringByAppendingFormat:@"<video controls=\"controls\" src=\"%@\" width=\"%.0f\" height=\"%.0f\" alt=\"%@\"></video>", photo.publishedURL, width, height, photo.altText];
				}
				else {
					s = [s stringByAppendingFormat:@"<img src=\"%@\" width=\"%.0f\" height=\"%.0f\" alt=\"%@\">", photo.publishedURL, width, height, photo.altText];
				}
			}
		}

		[self uploadText:s];
	}
}

- (void) uploadPhoto:(RFPhoto *)photo completion:(void (^)(void))handler
{
	if (self.attachedPhotos.count > 0) {
		[self showProgressHeader:@"Uploading photos..."];
	}
	else if (photo.isVideo) {
		[self showProgressHeader:@"Uploading video..."];
	}
	else {
		[self showProgressHeader:@"Uploading photo..."];
	}
	
	NSData* d;
	
	if (photo.isVideo) {
		d = [NSData dataWithContentsOfURL:photo.videoAsset.URL];
		[photo removeTemporaryVideo];
	}
	else if (photo.isGIF) {
		d = [NSData dataWithContentsOfURL:photo.fileURL];
	}
	else if (photo.isPNG) {
		d = [NSData dataWithContentsOfURL:photo.fileURL];
	}
	else {
		d = [photo jpegData];
	}
	
	if (d) {
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
			NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
			if (destination_uid == nil) {
				destination_uid = @"";
			}
			NSDictionary* args = @{
				@"mp-destination": destination_uid
			};
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args isVideo:photo.isVideo isGIF:photo.isGIF isPNG:photo.isPNG completion:^(UUHttpResponse* response) {
				NSDictionary* headers = response.httpResponse.allHeaderFields;
				NSString* image_url = headers[@"Location"];
				RFDispatchMainAsync (^{
					if (image_url == nil) {
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
					}
					else {
						photo.publishedURL = image_url;
						handler();
					}
				});
			}];
		}
		else if ([self hasMicropubBlog]) {
			NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubMediaEndpoint];
			RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
			NSDictionary* args = @{
			};
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args isVideo:photo.isVideo completion:^(UUHttpResponse* response) {
				NSDictionary* headers = response.httpResponse.allHeaderFields;
				NSString* image_url = headers[@"Location"];
				RFDispatchMainAsync (^{
					if (image_url == nil) {
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
					}
					else {
						photo.publishedURL = image_url;
						handler();
					}
				});
			}];
		}
		else {
			NSString* xmlrpc_endpoint = [RFSettings stringForKey:kExternalBlogEndpoint];
			NSString* blog_s = [RFSettings stringForKey:kExternalBlogID];
			NSString* username = [RFSettings stringForKey:kExternalBlogUsername];
			NSString* password = [SAMKeychain passwordForService:@"ExternalBlog" account:username];
			
			NSNumber* blog_id = [NSNumber numberWithInteger:[blog_s integerValue]];
			NSString* filename = [[[[NSString uuGenerateUUIDString] lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByAppendingPathExtension:@"jpg"];
			
			if (!blog_id || !username || !password) {
				[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Your blog settings were not saved correctly. Try signing out and trying again." button:@"OK" completionHandler:NULL];
				[self hideProgressHeader];
				self.photoButton.hidden = NO;
				return;
			}
			
			NSArray* params = @[ blog_id, username, password, @{
				@"name": filename,
				@"type": @"image/jpeg",
				@"bits": d
			}];
			NSString* method_name = @"metaWeblog.newMediaObject";

			RFXMLRPCRequest* request = [[RFXMLRPCRequest alloc] initWithURL:xmlrpc_endpoint];
			[request sendMethod:method_name params:params completion:^(UUHttpResponse* response) {
				RFXMLRPCParser* xmlrpc = [RFXMLRPCParser parsedResponseFromData:response.rawResponse];
				RFDispatchMainAsync ((^{
					if (xmlrpc.responseFault) {
						NSString* s = [NSString stringWithFormat:@"%@ (error: %@)", xmlrpc.responseFault[@"faultString"], xmlrpc.responseFault[@"faultCode"]];
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:s button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
						self.photoButton.hidden = NO;
					}
					else {
						NSString* image_url = [[xmlrpc.responseParams firstObject] objectForKey:@"url"];
						if (image_url == nil) {
							image_url = [[xmlrpc.responseParams firstObject] objectForKey:@"link"];
						}
						
						if (image_url == nil) {
							[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
							[self hideProgressHeader];
							self.photoButton.hidden = NO;
						}
						else {
							photo.publishedURL = image_url;
							handler();
						}
					}
				}));
			}];
		}
	}
	else {
		[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Could not load photo data." button:@"OK" completionHandler:NULL];
		[self hideProgressHeader];
	}
}

- (void) clickedPhotoAtIndex:(NSIndexPath *)indexPath
{
	RFPhoto* photo = [self.attachedPhotos objectAtIndex:indexPath.item];
	self.altController = [[RFPhotoAltController alloc] initWithPhoto:photo atIndex:indexPath];
	[self.view.window beginSheet:self.altController.window completionHandler:^(NSModalResponse returnCode) {
        self.altController = nil;
	}];
}

- (void) removePhotoAtIndex:(NSIndexPath *)indexPath
{
	RFPhoto* photo = [self.attachedPhotos objectAtIndex:indexPath.item];
	[photo removeTemporaryVideo];

	NSMutableArray* new_photos = [self.attachedPhotos mutableCopy];
	[new_photos removeObjectAtIndex:indexPath.item];
	self.attachedPhotos = new_photos;
	[self.photosCollectionView deleteItemsAtIndexPaths:[NSSet setWithObject:indexPath]];

	if (self.attachedPhotos.count == 0) {
//		self.photosHeightConstraint.animator.constant = 0;
	}
}

- (void) checkMediaEndpoint
{
	if ([self hasMicropubBlog]) {
		NSString* media_endpoint = [RFSettings stringForKey:kExternalMicropubMediaEndpoint];
		if (media_endpoint.length == 0) {
			NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubPostingEndpoint];
			RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
			NSDictionary* args = @{
				@"q": @"config"
			};
			[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
				BOOL found = NO;
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
					NSString* new_endpoint = [response.parsedResponse objectForKey:@"media-endpoint"];
					if (new_endpoint) {
						[RFSettings setString:new_endpoint forKey:kExternalMicropubMediaEndpoint];
						found = YES;
					}
				}
				
				if (!found) {
					RFDispatchMain (^{
						[NSAlert rf_showOneButtonAlert:@"Error Checking Server" message:@"Micropub media-endpoint was not found." button:@"OK" completionHandler:NULL];
					});
				}
			}];
		}
	}
}

- (void) downloadCategories
{
	if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
		RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
		NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
		if (destination_uid == nil) {
			destination_uid = @"";
		}

		NSDictionary* args = @{
			@"q": @"category",
			@"mp-destination": destination_uid
		};
		
		[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
			if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
				NSArray* categories = [response.parsedResponse objectForKey:@"categories"];
				if (categories) {
					self.categories = categories;
					RFDispatchMain (^{
						if (self.editingPost && ([self.editingPost.categories count] > 0)) {
							self.isShowingCategories = YES;
							[self updateCategoriesPane];
						}
						[self.categoriesCollectionView reloadData];
					});
				}
			}
		}];
	}
}

- (void) downloadBlogs
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSDictionary* args = @{
		@"q": @"config",
		@"mp-destination": destination_uid
	};

	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			self.destinations = [response.parsedResponse objectForKey:@"destination"];

			NSArray* syndicate_to = [response.parsedResponse objectForKey:@"syndicate-to"];
			if (syndicate_to) {
				self.crosspostServices = syndicate_to;

				// select all cross-post options by default (if not editing)
				if (self.editingPost == nil) {
					NSMutableArray* selected_uids = [NSMutableArray array];
					for (NSDictionary* info in self.crosspostServices) {
						[selected_uids addObject:info[@"uid"]];
					}
					self.selectedCrosspostUIDs = selected_uids;
					RFDispatchMain (^{
						[self.categoriesCollectionView reloadData];
					});
				}
			}
		}
	}];
}

@end
