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
#import "RFBlogsController.h"
#import "RFMicropub.h"
#import "RFSettings.h"
#import "RFHighlightingTextStorage.h"
#import "UUString.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "SAMKeychain.h"
#import "NSAlert+Extras.h"
#import "NSImage+Extras.h"
#import "NSString+Extras.h"
#import "MMMarkdown.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

static NSString* const kPhotoCellIdentifier = @"PhotoCell";
static CGFloat const kTextViewTitleHiddenTop = 10;
static CGFloat const kTextViewTitleShownTop = 54;

@implementation RFPostController

- (id) init
{
	self = [super initWithNibName:@"Post" bundle:nil];
	if (self) {
		self.attachedPhotos = @[];
		self.queuedPhotos = @[];
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

- (void) viewDidLoad
{
	[super viewDidLoad];

	[self setupText];
	[self setupColletionView];
	[self setupBlogName];
	[self setupNotifications];
	
	[self updateTitleHeaderWithAnimation:NO];
}

- (void) viewDidAppear
{
	[super viewDidAppear];
}

- (void) setupText
{
	self.textStorage = [[RFHighlightingTextStorage alloc] init];
	[self.textStorage addLayoutManager:self.textView.layoutManager];

	self.textUndoManager = [[NSUndoManager alloc] init];

	self.view.layer.masksToBounds = YES;
	self.view.layer.cornerRadius = 10.0;
	self.view.layer.backgroundColor = [NSColor whiteColor].CGColor;
	
	if (self.replyUsername) {
		self.textView.string = [NSString stringWithFormat:@"@%@ ", self.replyUsername];
	}
	else if (self.initialText) {
		self.textView.string = self.initialText;
	}
	else {
		NSString* title = [RFSettings stringForKey:kLatestDraftTitlePrefKey];
		NSString* draft = [RFSettings stringForKey:kLatestDraftTextPrefKey];
		if (title) {
			self.titleField.stringValue = title;
		}
		if (draft) {
			self.textView.string = draft;
		}
	}
	
	NSFont* normal_font = [NSFont fontWithName:@"Avenir-Book" size:kDefaultFontSize];
	self.textView.typingAttributes = @{
		NSFontAttributeName: normal_font
	};
	
	self.textView.delegate = self;
	self.textView.textStorage.delegate = self;
	
	[self updateRemainingChars];
	
	if (self.isReply) {
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

- (void) setupColletionView
{
	self.photosCollectionView.delegate = self;
	self.photosCollectionView.dataSource = self;
	
	[self.photosCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"PhotoCell" bundle:nil] forItemWithIdentifier:kPhotoCellIdentifier];

	self.photosHeightConstraint.constant = 0;
}

- (void) setupDragging
{
	[self.textView registerForDraggedTypes:@[ NSFilenamesPboardType ]];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachFilesNotification:) name:kAttachFilesNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedBlogNotification:) name:kUpdatedBlogNotification object:nil];
	
}

- (void) blogNameClicked:(NSGestureRecognizer *)gesture
{
	[self showBlogsMenu];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(toggleTitleField:)) {
		if (self.isReply) {
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

		if (animate) {
			self.titleField.animator.alphaValue = 1.0;
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
				self.titleField.stringValue = @"";
			}];
		}
		else {
			self.titleField.alphaValue = 0.0;
			self.textTopConstraint.constant = kTextViewTitleHiddenTop;
			self.titleField.hidden = YES;
			self.titleField.stringValue = @"";
		}
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
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kLatestDraftTitlePrefKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kLatestDraftTextPrefKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kClosePostingNotification object:self];
}

- (void) finishClose
{
	if (!self.isReply && !self.isSent) {
		NSString* title = [self currentTitle];
		NSString* draft = [self currentText];
		[[NSUserDefaults standardUserDefaults] setObject:title forKey:kLatestDraftTitlePrefKey];
		[[NSUserDefaults standardUserDefaults] setObject:draft forKey:kLatestDraftTextPrefKey];
	}
}

- (IBAction) toggleTitleField:(id)sender
{
	self.isShowingTitle = !self.isShowingTitle;
	if (self.isShowingTitle) {
		[self.titleField becomeFirstResponder];
	}
	else {
		[self.textView.window makeFirstResponder:self.textView];
	}
	
	[self updateTitleHeader];
}

- (IBAction) close:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kClosePostingNotification object:self];
}

- (IBAction) choosePhoto:(id)sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[ @"public.image" ];
	panel.allowsMultipleSelection = YES;
	
	[panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			NSArray* urls = panel.URLs;
			NSMutableArray* new_photos = [self.attachedPhotos mutableCopy];
			
			for (NSURL* file_url in urls) {
				NSImage* img = [[NSImage alloc] initWithContentsOfURL:file_url];
				NSImage* scaled_img = [img rf_scaleToWidth:1200];
				RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];
				[new_photos addObject:photo];
			}

			self.attachedPhotos = new_photos;
			[self.photosCollectionView reloadData];

			self.photosHeightConstraint.animator.constant = 100;
			
			[self checkMediaEndpoint];
		}
		
		[self becomeFirstResponder];
	}];
}

- (void) textDidChange:(NSNotification *)notification
{
	[self updateRemainingChars];

	if (!self.isReply && ([self currentProcessedMarkup].length > 280)) {
		self.isShowingTitle = YES;
	}

	[self updateTitleHeader];
}

- (IBAction) titleFieldDidChange:(id)sender
{
	[self updateRemainingChars];
}

- (void) attachFilesNotification:(NSNotification *)notification
{
	NSArray* paths = [notification.userInfo objectForKey:kAttachFilesPathsKey];

	NSMutableArray* new_photos = [self.attachedPhotos mutableCopy];
	BOOL too_many_photos = NO;
	
	for (NSString* filepath in paths) {
		if (new_photos.count < 10) {
			NSImage* img = [[NSImage alloc] initWithContentsOfFile:filepath];
			NSImage* scaled_img = [img rf_scaleToWidth:1200];
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:scaled_img];
			[new_photos addObject:photo];
		}
		else {
			too_many_photos = YES;
		}
	}

	self.attachedPhotos = new_photos;
	[self.photosCollectionView reloadData];

	self.photosHeightConstraint.animator.constant = 100;

	[self checkMediaEndpoint];

	if (too_many_photos) {
		[NSAlert rf_showOneButtonAlert:@"Only 10 Photos Added" message:@"The first 10 photos were added to your post." button:@"OK" completionHandler:NULL];
	}
}

- (void) updatedBlogNotification:(NSNotification *)notification
{
	[self setupBlogName];
	[self hideBlogsMenu];
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.attachedPhotos.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFPhoto* photo = [self.attachedPhotos objectAtIndex:indexPath.item];
	
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	item.thumbnailImageView.image = photo.thumbnailImage;
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	NSIndexPath* index_path = [indexPaths anyObject];
	[self performSelector:@selector(removePhotoAtIndex:) withObject:index_path afterDelay:0.1];
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
	NSString* html = [MMMarkdown HTMLStringWithMarkdown:[self currentText] error:&error];
	if (html.length > 0) {
		// Markdown processor adds a return at the end
		html = [html substringToIndex:html.length - 1];
		html = [html stringByReplacingOccurrencesOfString:@"</p>\n<p>" withString:@"</p>\n\n<p>"];
	}
	
	return [html rf_stripHTML];
}

#pragma mark -

- (void) showBlogsMenu
{
	if (self.blogsMenuPopover) {
		[self hideBlogsMenu];
	}
	else {
		RFBlogsController* blogs_controller = [[RFBlogsController alloc] init];
		
		self.blogsMenuPopover = [[NSPopover alloc] init];
		self.blogsMenuPopover.contentViewController = blogs_controller;
		self.blogsMenuPopover.behavior = NSPopoverBehaviorTransient;

		NSRect r = self.blognameField.bounds;
		[self.blogsMenuPopover showRelativeToRect:r ofView:self.blognameField preferredEdge:NSRectEdgeMaxY];
	}
}

- (void) hideBlogsMenu
{
	if (self.blogsMenuPopover) {
		[self.blogsMenuPopover performClose:nil];
		self.blogsMenuPopover = nil;
	}
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
		[self.textView insertText:@"[]()"];
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
	self.postButton.enabled = NO;
	[self.progressSpinner startAnimation:nil];
}

- (void) hideProgressHeader
{
	self.postButton.enabled = YES;
	[self.progressSpinner stopAnimation:nil];
}

- (void) updateRemainingChars
{
	if (!self.isReply && [self currentTitle].length > 0) {
		self.remainingField.hidden = YES;
	}
	else {
		self.remainingField.hidden = NO;
	}

	NSInteger max_chars = 280;
	NSInteger num_chars = [self currentProcessedMarkup].length;
	NSInteger num_remaining = max_chars - num_chars;

	NSString* s = [NSString stringWithFormat:@"%ld/%ld", (long)num_chars, (long)max_chars];
	NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:s];
	NSUInteger num_len = [[s componentsSeparatedByString:@"/"] firstObject].length;

	NSMutableParagraphStyle* para = [[NSMutableParagraphStyle alloc] init];
	para.alignment = NSTextAlignmentRight;
	[attr addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange (0, s.length)];

	if (num_chars <= 140) {
		[attr addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:0.2588 green:0.5450 blue:0.7921 alpha:1.0] range:NSMakeRange (0, num_len)];
		self.remainingField.attributedStringValue = attr;
	}
	else if (num_remaining < 0) {
		[attr addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:1.0 green:0.3764 blue:0.3411 alpha:1.0] range:NSMakeRange (0, num_len)];
		self.remainingField.attributedStringValue = attr;
	}
	else {
		[attr addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange (0, num_len)];
	}

	self.remainingField.attributedStringValue = attr;
}

- (void) uploadText:(NSString *)text
{
	if (self.isReply) {
		[self showProgressHeader:@"Now sending your reply..."];
		RFClient* client = [[RFClient alloc] initWithPath:@"/posts/reply"];
		NSDictionary* args = @{
			@"id": self.replyPostID,
			@"text": text
		};
		[client postWithParams:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
//				[Answers logCustomEventWithName:@"Sent Reply" customAttributes:nil];
				[self closeWithoutSaving];
			});
		}];
	}
	else {
		[self showProgressHeader:@"Now publishing to your microblog..."];
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
			NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
			NSDictionary* args;
			if ([self.attachedPhotos count] > 0) {
				NSMutableArray* photo_urls = [NSMutableArray array];
				for (RFPhoto* photo in self.attachedPhotos) {
					[photo_urls addObject:photo.publishedURL];
				}
				
				args = @{
					@"name": [self currentTitle],
					@"content": text,
					@"photo[]": photo_urls
				};
			}
			else {
				args = @{
					@"name": [self currentTitle],
					@"content": text
				};
			}

			[client postWithParams:args completion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
						[self hideProgressHeader];
						NSString* msg = response.parsedResponse[@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
					}
					else {
//						[Answers logCustomEventWithName:@"Sent Post" customAttributes:nil];
						[self closeWithoutSaving];
					}
				});
			}];
		}
		else if ([self hasMicropubBlog]) {
			NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubPostingEndpoint];
			RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
			NSDictionary* args;
			if ([self.attachedPhotos count] > 0) {
				NSMutableArray* photo_urls = [NSMutableArray array];
				for (RFPhoto* photo in self.attachedPhotos) {
					[photo_urls addObject:photo.publishedURL];
				}

				if (photo_urls.count == 1) {
					args = @{
						@"h": @"entry",
						@"name": [self currentTitle],
						@"content": text,
						@"photo": [photo_urls firstObject]
					};
				}
				else {
					args = @{
						@"h": @"entry",
						@"name": [self currentTitle],
						@"content": text,
						@"photo[]": photo_urls
					};
				}
			}
			else {
				args = @{
					@"h": @"entry",
					@"name": [self currentTitle],
					@"content": text
				};
			}
			
			[client postWithParams:args completion:^(UUHttpResponse* response) {
				RFDispatchMainAsync (^{
					if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
						[self hideProgressHeader];
						NSString* msg = response.parsedResponse[@"error_description"];
						[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
					}
					else {
//						[Answers logCustomEventWithName:@"Sent Post" customAttributes:nil];
						[self closeWithoutSaving];
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
					else {
//						[Answers logCustomEventWithName:@"Sent External" customAttributes:nil];
						[self closeWithoutSaving];
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
		
		[self uploadPhoto:photo completion:^{
			[self uploadNextPhoto];
		}];
	}
	else {
		NSString* s = [self currentText];
		
		if ([self prefersExternalBlog] && ![self hasMicropubBlog]) {
			if (s.length > 0) {
				s = [s stringByAppendingString:@"\n\n"];
			}
			
			for (RFPhoto* photo in self.attachedPhotos) {
				s = [s stringByAppendingFormat:@"<img src=\"%@\" width=\"%.0f\" height=\"%.0f\" />", photo.publishedURL, 600.0, 600.0];
			}
		}

		[self uploadText:s];
	}
}

- (void) uploadPhoto:(RFPhoto *)photo completion:(void (^)())handler
{
	if (self.attachedPhotos.count > 0) {
		[self showProgressHeader:@"Uploading photos..."];
	}
	else {
		[self showProgressHeader:@"Uploading photo..."];
	}
	
	NSData* d = [photo jpegData];
	if (d) {
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
			NSDictionary* args = @{
			};
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
				NSDictionary* headers = response.httpResponse.allHeaderFields;
				NSString* image_url = headers[@"Location"];
				RFDispatchMainAsync (^{
					if (image_url == nil) {
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
					}
					else {
						photo.publishedURL = image_url;
//						[Answers logCustomEventWithName:@"Uploaded Photo" customAttributes:nil];
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
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
				NSDictionary* headers = response.httpResponse.allHeaderFields;
				NSString* image_url = headers[@"Location"];
				RFDispatchMainAsync (^{
					if (image_url == nil) {
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
						[self hideProgressHeader];
					}
					else {
						photo.publishedURL = image_url;
//						[Answers logCustomEventWithName:@"Uploaded Micropub" customAttributes:nil];
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

//							[Answers logCustomEventWithName:@"Uploaded External" customAttributes:nil];
							handler();
						}
					}
				}));
			}];
		}
	}
}

- (void) removePhotoAtIndex:(NSIndexPath *)indexPath
{
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

@end
