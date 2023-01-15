//
//  RFInstagramController.m
//  Snippets
//
//  Created by Manton Reece on 5/2/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFInstagramController.h"

#import "RFPhotoCell.h"
#import "RFSettings.h"
#import "RFPhoto.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "UUString.h"
#import "UUDate.h"
#import "NSAlert+Extras.h"
#import "SAMKeychain.h"
#import "RFMacros.h"
#import "RFConstants.h"

static NSString* const kPhotoCellIdentifier = @"PhotoCell";

@implementation RFInstagramController

- (instancetype) initWithFile:(NSString *)path
{
	self = [super initWithWindowNibName:@"Instagram"];
	if (self) {
		// content/posts_1.json
		self.path = path;
		self.folder = [[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
		
		[self setupPhotos];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupHostname];
	[self setupSummary];
	[self setupCollectionView];
}

- (void) setupPhotos
{
	NSData* d = [NSData dataWithContentsOfFile:self.path];
	NSError* e = nil;
	NSArray* photos = [NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
	self.photos = [photos sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* info1, NSDictionary* info2) {
		NSArray* media1 = [info1 objectForKey:@"media"];
		NSArray* media2 = [info2 objectForKey:@"media"];
		NSDictionary* photo1 = [media1 firstObject];
		NSDictionary* photo2 = [media2 firstObject];
		NSNumber* num1 = [photo1 objectForKey:@"creation_timestamp"];
		NSNumber* num2 = [photo2 objectForKey:@"creation_timestamp"];
		return [num1 compare:num2];
	}];
}

- (void) setupHostname
{
	if ([self hasAnyBlog]) {
		if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
			NSString* s = [RFSettings stringForKey:kCurrentDestinationName];
			if (s) {
				self.hostnameField.stringValue = s;
			}
			else {
				self.hostnameField.stringValue = [RFSettings stringForKey:kAccountDefaultSite];
			}
		}
		else if ([self hasMicropubBlog]) {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalMicropubMe];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.hostnameField.stringValue = endpoint_url.host;
		}
		else {
			NSString* endpoint_s = [RFSettings stringForKey:kExternalBlogEndpoint];
			NSURL* endpoint_url = [NSURL URLWithString:endpoint_s];
			self.hostnameField.stringValue = endpoint_url.host;
		}
	}
	else {
		self.hostnameField.stringValue = @"No blog configured.";
		self.importButton.enabled = NO;
	}
}

- (void) setupSummary
{
	NSInteger num_selected = [self.collectionView selectionIndexPaths].count;
	
	if (self.photos.count == 1) {
		self.summaryField.stringValue = [NSString stringWithFormat:@"1 post (%lu selected)", (unsigned long)num_selected];
	}
	else {
		self.summaryField.stringValue = [NSString stringWithFormat:@"%lu posts (%lu selected)", (unsigned long)self.photos.count, (unsigned long)num_selected];
	}
	
	if ((num_selected > 0) && [self hasAnyBlog]) {
		self.importButton.enabled = YES;
	}
	else {
		self.importButton.enabled = NO;
	}
}

- (void) setupCollectionView
{
	self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
	
	[self.collectionView registerNib:[[NSNib alloc] initWithNibNamed:@"PhotoCell" bundle:nil] forItemWithIdentifier:kPhotoCellIdentifier];
}

#pragma mark -

- (void) startProgress
{
	self.summaryField.hidden = YES;
	self.progressBar.hidden = NO;
	[self.progressBar startAnimation:nil];
	self.importButton.title = @"Stop";
	self.isImporting = YES;
	self.isStopping = NO;
}

- (void) stopProgress
{
	self.summaryField.hidden = NO;
	self.progressBar.hidden = YES;
	[self.progressBar stopAnimation:nil];
	self.importButton.title = @"Import";
	self.isImporting = NO;
	self.isStopping = YES;
}

- (void) queueSelected
{
	self.queued = [NSMutableArray array];

	NSArray* selected_indexes = [self.collectionView.selectionIndexPaths allObjects];

	self.batchTotal = selected_indexes.count;
	self.progressBar.doubleValue = 0.0;
	
	for (NSIndexPath* index_path in selected_indexes) {
		NSDictionary* photo = [self.photos objectAtIndex:index_path.item];
		[self.queued addObject:photo];
	}
}

- (IBAction) import:(id)sender
{
	if (self.isImporting) {
		[self stopProgress];
	}
	else {
		[self queueSelected];
		[self startProgress];
		[self importNextPhoto];
	}
}

- (void) importPhoto:(NSDictionary *)info
{
	NSArray* media = [info objectForKey:@"media"];
    NSDictionary* photo = [media firstObject];
    NSString* caption;
    if(media.count == 1){
        caption = [photo objectForKey:@"title"];
    }else{
        caption = [info objectForKey:@"title"];
    }
		
		NSString* relative_path = [photo objectForKey:@"uri"];
		NSNumber* taken_at = [photo objectForKey:@"creation_timestamp"];

		NSString* current_file = self.folder;
		NSArray* components = [relative_path componentsSeparatedByString:@"/"];
		for (NSString* filename in components) {
			current_file = [current_file stringByAppendingPathComponent:filename];
		}

		NSImage* img = [[NSImage alloc] initWithContentsOfFile:current_file];
		if (img) {
			NSDate* d = [NSDate dateWithTimeIntervalSince1970:[taken_at unsignedLongValue]];
			
	//		NSDate* d = [NSDate uuDateFromRfc3339String:taken_at];
	//		if (d == nil) {
	//			d = [NSDate uuDateFromString:taken_at withFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
	//		}
			
			RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:img];
			[self uploadPhoto:photo completion:^{
				NSString* s = caption;
				
				if ((s.length > 0) && ([s characterAtIndex:0] == '@')) {
					// chop off the first "@" to avoid @-mentions
					s = [s substringFromIndex:1];
				}
				
				if ([self prefersExternalBlog] && ![self hasMicropubBlog]) {
					if (s.length > 0) {
						s = [s stringByAppendingString:@"\n\n"];
					}

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

					s = [s stringByAppendingFormat:@"<img src=\"%@\" width=\"%.0f\" height=\"%.0f\">", photo.publishedURL, width, height];
				}

				[self uploadText:s date:d forPhoto:photo completion:^{
					[self importNextPhoto];
				}];
			}];
		}
		else {
			[self importNextPhoto];
		}
}

- (void) importNextPhoto
{
	if (self.isStopping) {
		return;
	}

	NSInteger total = self.batchTotal;
	NSInteger remaining = self.queued.count;
	NSInteger progress = total - remaining;

	self.progressBar.doubleValue = (float)progress / total;

	NSDictionary* photo = [self.queued firstObject];
	if (photo) {
		[self.queued removeObjectAtIndex:0];
		[self importPhoto:photo];
	}
	else {
		self.summaryField.stringValue = @"Import finished";
		self.summaryField.hidden = NO;
		self.progressBar.hidden = YES;
		[self stopProgress];
	}
}

#pragma mark -

- (BOOL) hasAnyBlog
{
	BOOL has_hosted = [RFSettings boolForKey:kHasSnippetsBlog];
	NSString* micropub = [RFSettings stringForKey:kExternalMicropubMe];
	NSString* xmlrpc = [RFSettings stringForKey:kExternalBlogEndpoint];
	return (has_hosted || micropub || xmlrpc);
}

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

- (void) uploadPhoto:(RFPhoto *)photo completion:(void (^)(void))handler
{
	NSData* d = [photo jpegData];
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
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args isVideo:photo.isVideo isGIF:NO isPNG:NO completion:^(UUHttpResponse* response) {
				NSDictionary* headers = response.httpResponse.allHeaderFields;
				NSString* image_url = headers[@"Location"];
				RFDispatchMainAsync (^{
					if (image_url == nil) {
						[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
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
					}
					else {
						NSString* image_url = [[xmlrpc.responseParams firstObject] objectForKey:@"url"];
						if (image_url == nil) {
							image_url = [[xmlrpc.responseParams firstObject] objectForKey:@"link"];
						}
						
						if (image_url == nil) {
							[NSAlert rf_showOneButtonAlert:@"Error Uploading Photo" message:@"Photo URL was blank." button:@"OK" completionHandler:NULL];
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
}

- (void) uploadText:(NSString *)text date:(NSDate *)date forPhoto:(RFPhoto *)photo completion:(void (^)(void))handler
{
	if ([self hasSnippetsBlog] && ![self prefersExternalBlog]) {
		RFClient* client = [[RFClient alloc] initWithPath:@"/micropub"];
		NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
		if (destination_uid == nil) {
			destination_uid = @"";
		}
		NSDictionary* args = @{
			@"name": @"",
			@"content": text,
			@"photo": photo.publishedURL,
			@"published": [date uuRfc3339StringForUTCTimeZone],
			@"mp-destination": destination_uid,
            @"category": [NSArray arrayWithObjects: @"Instagram",nil]
		};

		[client postWithParams:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
					NSString* msg = response.parsedResponse[@"error_description"];
					[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
				}
				else {
					handler();
				}
			});
		}];
	}
	else if ([self hasMicropubBlog]) {
		NSString* micropub_endpoint = [RFSettings stringForKey:kExternalMicropubPostingEndpoint];
		RFMicropub* client = [[RFMicropub alloc] initWithURL:micropub_endpoint];
		NSDictionary* args = @{
			@"h": @"entry",
			@"name": @"",
			@"content": text,
			@"photo": photo.publishedURL,
			@"published": [date uuRfc3339StringForUTCTimeZone],
            @"category": [NSArray arrayWithObjects: @"Instagram",nil]
		};
		
		[client postWithParams:args completion:^(UUHttpResponse* response) {
			RFDispatchMainAsync (^{
				if (response.parsedResponse && [response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
					NSString* msg = response.parsedResponse[@"error_description"];
					[NSAlert rf_showOneButtonAlert:@"Error Sending Post" message:msg button:@"OK" completionHandler:NULL];
				}
				else {
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
			content[@"post_title"] = @"";
			content[@"post_content"] = post_text;
			content[@"post_date"] = date;
			if (post_format.length > 0) {
				content[@"post_format"] = post_format;
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
				}
				else {
					handler();
				}
			}));
		}];
	}
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.photos.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	item.thumbnailImageView.image = nil;
	
	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		item.selectionOverlayView.layer.opacity = 0.4;
		item.selectionOverlayView.layer.backgroundColor = [NSColor blackColor].CGColor;
	}

	[self setupSummary];
}

- (void) collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	for (NSIndexPath* index_path in indexPaths) {
		RFPhotoCell* item = (RFPhotoCell *)[collectionView itemAtIndexPath:index_path];
		item.selectionOverlayView.layer.opacity = 0.0;
		item.selectionOverlayView.layer.backgroundColor = nil;
	}

	[self setupSummary];
}

- (void) collectionView:(NSCollectionView *)collectionView willDisplayItem:(NSCollectionViewItem *)item forRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary* info = [self.photos objectAtIndex:indexPath.item];
	NSArray* media = [info objectForKey:@"media"];
	
//	"media": [
//	  {
//		"uri": "media/posts/201210/11202472_417504411766906_988056863_n_17842263256015623.jpg",
//		"creation_timestamp": 1350766513,
//		"title": "Pumpkins"
//	  }
//	]
	
	NSDictionary* photo = [media firstObject];
	NSString* relative_path = [photo objectForKey:@"uri"];

	NSString* current_file = self.folder;
	NSArray* components = [relative_path componentsSeparatedByString:@"/"];
	for (NSString* filename in components) {
		current_file = [current_file stringByAppendingPathComponent:filename];
	}

	NSImage* img;

	NSString* e = [[current_file pathExtension] lowercaseString];
	if ([e isEqualToString:@"mov"] || [e isEqualToString:@"m4v"] || [e isEqualToString:@"mp4"]) {
		if (@available(macOS 11.0, *)) {
			img = [NSImage imageWithSystemSymbolName:@"film" accessibilityDescription:@""];
		}
	}
	else {
		img = [[NSImage alloc] initWithContentsOfFile:current_file];
	}

	RFPhotoCell* photo_item = (RFPhotoCell *)item;
	if (photo_item.thumbnailImageView.image == nil) {
		photo_item.thumbnailImageView.image = img;
	}
}

@end
