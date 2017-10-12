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

static NSString* const kAttachPhotoNotification = @"RFAttachPhotoNotification";
static NSString* const kAttachPhotoKey = @"photo";

@interface RFPhoto : NSObject

@property (strong) PHAsset* asset;
@property (strong) NSImage* thumbnailImage;
@property (strong) NSString* publishedURL;

- (id) initWithAsset:(PHAsset *)asset;
- (id) initWithThumbnail:(NSImage *)image;

- (NSData *) jpegData;

@end
