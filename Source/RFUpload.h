//
//  RFUpload.h
//  Snippets
//
//  Created by Manton Reece on 7/14/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFUpload : NSObject

@property (strong) NSImage* cachedImage;
@property (strong) NSImage* cachedPoster;
@property (strong) NSString* url;
@property (strong) NSString* thumbnail_url;
@property (strong) NSString* poster_url;
@property (strong) NSString* alt;
@property (assign) BOOL isAI;
@property (assign) NSInteger width;
@property (assign) NSInteger height;
@property (strong) NSDate* createdAt;

- (instancetype) initWithURL:(NSString *)url;

- (NSString *) filename;
- (BOOL) isPhoto;
- (BOOL) isVideo;
- (BOOL) isAudio;

- (NSString *) htmlTag;
- (void) ensureDimensionsWithCompletion:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
