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
		self.path = path;
		self.folder = [path stringByDeletingLastPathComponent];
		
		[self setupPhotos];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupHostname];
	[self setupSummary];
	[self setupColletionView];
}

- (void) setupPhotos
{
	NSData* d = [NSData dataWithContentsOfFile:self.path];
	NSError* e = nil;
	NSDictionary* obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
	self.photos = [obj objectForKey:@"photos"];
}

- (void) setupHostname
{
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

- (void) setupSummary
{
	if (self.photos.count == 1) {
		self.summaryField.stringValue = @"1 photo";
	}
	else {
		self.summaryField.stringValue = [NSString stringWithFormat:@"%lu photos", (unsigned long)self.photos.count];
	}
}

- (void) setupColletionView
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

- (IBAction) import:(id)sender
{
	if (self.isImporting) {
		[self stopProgress];
	}
	else {
		self.queued = [self.photos mutableCopy];
		[self startProgress];
		[self importNextPhoto];
	}
}

- (void) importPhoto:(NSDictionary *)info
{
	NSString* caption = [info objectForKey:@"caption"];
	NSString* relative_path = [info objectForKey:@"path"];
	NSString* taken_at = [info objectForKey:@"taken_at"];

	NSString* current_file = self.folder;
	NSArray* components = [relative_path componentsSeparatedByString:@"/"];
	for (NSString* filename in components) {
		current_file = [current_file stringByAppendingPathComponent:filename];
	}

	NSImage* img = [[NSImage alloc] initWithContentsOfFile:current_file];
	if (img) {
		NSDate* d = [NSDate uuDateFromString:taken_at withFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
		
		RFPhoto* photo = [[RFPhoto alloc] initWithThumbnail:img];
		[self uploadPhoto:photo completion:^{
			NSString* s = caption;
			
			if ([self prefersExternalBlog] && ![self hasMicropubBlog]) {
				if (s.length > 0) {
					s = [s stringByAppendingString:@"\n\n"];
				}
				
				s = [s stringByAppendingFormat:@"<img src=\"%@\" width=\"%.0f\" height=\"%.0f\" />", photo.publishedURL, 600.0, 600.0];
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

	NSInteger total = self.photos.count;
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
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
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
			[client uploadImageData:d named:@"file" httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
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
			@"mp-destination": destination_uid
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
			@"published": [date uuRfc3339StringForUTCTimeZone]
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
	NSDictionary* photo = [self.photos objectAtIndex:indexPath.item];

//      "caption": "More basketball on TV today",
//      "path": "photos/201704/8674986dfc70767c44dc92d50e81b897.jpg",
//      "taken_at": "2017-04-16T12:08:35"

	NSString* relative_path = [photo objectForKey:@"path"];

	NSString* current_file = self.folder;
	NSArray* components = [relative_path componentsSeparatedByString:@"/"];
	for (NSString* filename in components) {
		current_file = [current_file stringByAppendingPathComponent:filename];
	}

	NSImage* img = [[NSImage alloc] initWithContentsOfFile:current_file];

	RFPhotoCell* item = (RFPhotoCell *)[collectionView makeItemWithIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
	item.thumbnailImageView.image = img;
	
	return item;
}

@end
