//
//  RFPhoto.m
//  Micro.blog
//
//  Created by Manton Reece on 3/22/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPhoto.h"

#import "SDAVAssetExportSession.h"

static CGFloat const kMaxVideoLandscapeWidth = 1920.0;
static CGFloat const kMaxVideoLandscapeHeight = 1080.0;

@implementation RFPhoto

#if 0 // 10.13

- (id) initWithAsset:(PHAsset *)asset
{
	self = [super init];
	if (self) {
		self.asset = asset;
		self.altText = @"";
	}
	
	return self;
}

#endif

- (id) initWithThumbnail:(NSImage *)image
{
	self = [super init];
	if (self) {
		self.thumbnailImage = image;
		self.altText = @"";
	}
	
	return self;
}

- (NSData *) jpegData
{
	NSBitmapImageRep* rep = (NSBitmapImageRep *)self.thumbnailImage.representations.firstObject;
	NSDictionary* props = @{ NSImageCompressionFactor: @0.8 };
	NSData* d = [rep representationUsingType:NSBitmapImageFileTypeJPEG properties:props];
	return d;
}

- (void) transcodeVideo:(void(^)(NSURL* url))completionBlock
{
	NSString* destination = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	destination = [destination stringByAppendingPathExtension:@"mov"];
	AVAsset* asset = self.videoAsset;
	
	NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
	AVAssetTrack* videoTrack = [videoTracks objectAtIndex:0];
	CGSize size = CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform);
	size.width = fabs(size.width);
	size.height = fabs(size.height);
	
	SDAVAssetExportSession* exportSession = [[SDAVAssetExportSession alloc] initWithAsset:asset];
	exportSession.outputURL = [NSURL fileURLWithPath:destination];
	exportSession.outputFileType = AVFileTypeAppleM4V;
	exportSession.videoSettings = [self videoSettingsForSize:size];
	exportSession.audioSettings = [self audioSettings];
	
	[exportSession exportAsynchronouslyWithCompletionHandler:^{
		self.tempVideoPath = destination;
		dispatch_sync (dispatch_get_main_queue(), ^{
			completionBlock(exportSession.outputURL);
		});
	}];
}

- (NSInteger) evenVideoDimension:(CGFloat)value
{
	NSInteger result = (NSInteger)floor(value);
	if ((result % 2) != 0) {
		result--;
	}
	if (result < 2) {
		result = 2;
	}

	return result;
}

- (NSDictionary *) videoSettingsForSize:(CGSize)size
{
	NSInteger new_width;
	NSInteger new_height;

	if ((size.width == 0) || (size.height == 0)) {
		new_width = 640;
		new_height = 480;
	}
	else {
		CGFloat max_width = kMaxVideoLandscapeWidth;
		CGFloat max_height = kMaxVideoLandscapeHeight;
		if (size.height > size.width) {
			max_width = kMaxVideoLandscapeHeight;
			max_height = kMaxVideoLandscapeWidth;
		}

		CGFloat scale = MIN(max_width / size.width, max_height / size.height);
		if (scale > 1.0) {
			scale = 1.0;
		}

		new_width = [self evenVideoDimension:(size.width * scale)];
		new_height = [self evenVideoDimension:(size.height * scale)];
	}

	return @{
			 AVVideoCodecKey: AVVideoCodecTypeH264,
			 AVVideoWidthKey: @(new_width),
			 AVVideoHeightKey: @(new_height),
			 AVVideoCompressionPropertiesKey: @{
					 AVVideoAverageBitRateKey: @3000000,
					 AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
					 }
			 };
}

- (NSDictionary *) audioSettings
{
	return @{
			 AVFormatIDKey: @(kAudioFormatMPEG4AAC),
			 AVNumberOfChannelsKey: @1,
			 AVSampleRateKey: @44100,
			 AVEncoderBitRateKey: @128000,
			 };
}

- (void) removeTemporaryVideo
{
	if (self.tempVideoPath.length > 0) {
		BOOL is_dir = NO;
		NSFileManager* fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:self.tempVideoPath isDirectory:&is_dir]) {
			if (!is_dir) {
				[fm removeItemAtPath:self.tempVideoPath error:NULL];
			}
		}
	}
}

@end
