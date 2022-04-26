//
//  RFPhoto.h
//  Micro.blog
//
//  Created by Manton Reece on 3/22/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>

static NSString* const kAttachPhotoNotification = @"RFAttachPhotoNotification";
static NSString* const kAttachPhotoKey = @"photo";

@interface RFPhoto : NSObject

//@property (strong) PHAsset* asset;
@property (strong) NSImage* thumbnailImage;
@property (strong) NSString* publishedURL;
@property (strong) NSString* altText;
@property (strong) NSURL* fileURL;
@property (strong) AVURLAsset* videoAsset;
@property (assign) BOOL isVideo;
@property (assign) BOOL isGIF;
@property (assign) BOOL isPNG;
@property (strong) NSString* tempVideoPath;

//- (id) initWithAsset:(PHAsset *)asset;
- (id) initWithThumbnail:(NSImage *)image;

- (NSData *) jpegData;
- (void) transcodeVideo:(void(^)(NSURL* url))completionBlock;
- (NSDictionary *) videoSettingsForSize:(CGSize)size;
- (NSDictionary *) audioSettings;
- (void) removeTemporaryVideo;

@end
