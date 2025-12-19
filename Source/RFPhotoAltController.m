//
//  RFPhotoAltController.m
//  Snippets
//
//  Created by Manton Reece on 1/12/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFPhotoAltController.h"

#import "RFPhoto.h"
#import "RFHighlightingTextStorage.h"
#import "RFConstants.h"
#import "RFSettings.h"
#import "RFClient.h"
#import "RFMacros.h"

static NSInteger const kMaxAltTextChecks = 20;

@implementation RFPhotoAltController

- (id) initWithPhoto:(RFPhoto *)photo atIndex:(NSIndexPath *)indexPath
{
	self = [super initWithWindowNibName:@"PhotoAlt"];
	if (self) {
		self.photo = photo;
		self.indexPath = indexPath;
		self.numAltChecks = 0;
	}
	
	return self;
}

- (void) dealloc
{
	[self.altTextTimer invalidate];
	self.altTextTimer = nil;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupPhotoThumbnail];
	[self setupText];
	[self setupDefaultButton];
	
	BOOL is_using_ai = [RFSettings boolForKey:kIsUsingAI];
	if (is_using_ai) {
		[self startUpload];
	}
}

- (void) setupPhotoThumbnail
{
	self.imageView.image = self.photo.thumbnailImage;
}

- (void) setupText
{
	NSFont* system_font = [NSFont systemFontOfSize:14];
	self.descriptionField.font = system_font;
	self.descriptionField.delegate = self;

	if (self.photo.altText.length > 0) {
		self.descriptionField.string = self.photo.altText;
	}
}

- (void) setupDefaultButton
{
	if (self.photo.altText.length > 0) {
		self.okButton.title = @"Update";
	}
}

- (IBAction) okPressed:(id)sender
{
	self.isCancelled = YES;
	self.photo.altText = [self.descriptionField string];
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) cancelPressed:(id)sender
{
	self.isCancelled = YES;
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) removePressed:(id)sender
{
	self.isCancelled = YES;
	if (self.photo.publishedURL && !self.photo.isUndeletable) {
		// if already uploaded, we need to also delete it
		[self removeUpload:self.photo.publishedURL completion:^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kRemoveAttachedPhotoNotification object:self userInfo:@{ kRemoveAttachedPhotoIndexPath: self.indexPath }];
			[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
		}];
	}
	else {
		[[NSNotificationCenter defaultCenter] postNotificationName:kRemoveAttachedPhotoNotification object:self userInfo:@{ kRemoveAttachedPhotoIndexPath: self.indexPath }];
		[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
	}
}

- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	if ([replacementString isEqualToString:@"\n"]) {
		[self.okButton performClick:nil];
		return NO;
	}
	else {
		return YES;
	}
}

- (void) startUpload
{
	// skip videos since they don't get alt text anyway
	if (self.photo.isVideo) {
		return;
	}
		
	// don't upload if we already have alt text
	if (self.photo.altText.length > 0) {
		return;
	}

	// don't upload if already uploaded
	if ([self.photo.publishedURL length] > 0) {
		[self waitForAltText];
		return;
	}

	[self.progressSpinner startAnimation:nil];
	self.progressStatusField.hidden = NO;
	self.progressStatusField.stringValue = @"Uploading...";

	NSData* d = nil;
	NSString* filename = self.photo.fileURL.lastPathComponent;
	if (self.photo.isGIF || self.photo.isPNG) {
		d = [NSData dataWithContentsOfURL:self.photo.fileURL];
	}
	if (!d) {
		d = [self.photo jpegData];
	}
	if (!d) {
		[self.progressSpinner stopAnimation:nil];
		self.progressStatusField.stringValue = @"Failed to load image";
		return;
	}
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSDictionary* args = [RFSettings networkingArgsForDestination];

	[client uploadImageData:d named:@"file" filename:filename httpMethod:@"POST" queryArguments:args isVideo:self.photo.isVideo isGIF:self.photo.isGIF isPNG:self.photo.isPNG completion:^(UUHttpResponse* response) {
		if (self.isCancelled) {
			return;
		}

		NSDictionary *headers = response.httpResponse.allHeaderFields;
		NSString* image_url = headers[@"Location"];
		RFDispatchMainAsync(^{
			if (image_url.length > 0) {
				self.photo.publishedURL = image_url;
				[self waitForAltText];
			}
			else {
				[self.progressSpinner stopAnimation:nil];
				self.progressStatusField.stringValue = @"Upload failed";
			}
		});
	}];
}

- (void) waitForAltText
{
	[self.progressSpinner startAnimation:nil];
	self.progressStatusField.hidden = NO;
	self.progressStatusField.stringValue = @"Generating text...";
	
	self.altTextTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:NO block:^(NSTimer* timer) {
		if (self.isCancelled) {
			return;
		}
		
		self.numAltChecks += 1;
		
		// give up eventually
		if (self.numAltChecks > kMaxAltTextChecks) {
			[self.progressSpinner stopAnimation:nil];
			self.progressStatusField.stringValue = @"";
			return;
		}
		
		RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
		NSMutableDictionary* args = [[RFSettings networkingArgsForDestination] mutableCopy];
		[args setObject:@"source" forKey:@"q"];

		[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
				NSArray* items = response.parsedResponse[@"items"];
				NSDictionary* latest = [self findInfoWithItems:items forURL:self.photo.publishedURL];
				if (latest == nil) {
					RFDispatchMainAsync(^{
						[self.progressSpinner stopAnimation:nil];
						self.progressStatusField.stringValue = @"";
					});
					return;
				}
				
				// we always prefer no quotes
				NSString* alt_text = [latest objectForKey:@"alt"];
				alt_text = [alt_text stringByReplacingOccurrencesOfString:@"\"" withString:@""];
				
				RFDispatchMainAsync(^{
					if (alt_text.length > 0) {
						[self.progressSpinner stopAnimation:nil];
						self.progressStatusField.stringValue = @"";

						if (self.descriptionField.string.length == 0) {
							self.descriptionField.string = alt_text;
						}
					}
					else {
						[self waitForAltText];
					}
				});
			}
			else {
				RFDispatchMainAsync(^{
					[self.progressSpinner stopAnimation:nil];
					self.progressStatusField.stringValue = @"";
				});
			}
		}];
	}];
}

- (NSDictionary *) findInfoWithItems:(NSArray *)items forURL:(NSString *)url
{
	NSDictionary* result = nil;

	for (NSDictionary* item in items) {
		if ([[item objectForKey:@"url"] isEqualToString:url]) {
			result = item;
			break;
		}
	}
	
	return result;
}

- (void) removeUpload:(NSString *)url completion:(void (^)(void))handler
{
	[self.progressSpinner startAnimation:nil];
	self.progressStatusField.stringValue = @"Removing...";

	self.okButton.enabled = NO;
	self.cancelButton.enabled = NO;
	self.removeButton.enabled = NO;

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media"];
	NSMutableDictionary* args = [[RFSettings networkingArgsForDestination] mutableCopy];
	[args setObject:@"delete" forKey:@"action"];
	[args setObject:self.photo.publishedURL forKey:@"url"];
	
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			handler();
		});
	}];
}

@end
