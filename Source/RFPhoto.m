//
//  RFPhoto.m
//  Micro.blog
//
//  Created by Manton Reece on 3/22/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPhoto.h"

#import "SDAVAssetExportSession.h"

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
	
	[exportSession exportAsynchronouslyWithCompletionHandler:^
	 {
		 self.tempVideoPath = destination;
		 completionBlock(exportSession.outputURL);
	 }];

}

- (NSDictionary *) videoSettingsForSize:(CGSize)size
{
	NSInteger new_width;
	NSInteger new_height;
	
	if ((size.width == 0) || (size.height == 0)) {
		new_width = 640;
		new_height = 480;
	}
	else if ((size.width > 640) && (size.height > 640)) {
		if (size.width > size.height) {
			new_width = 640;
			new_height = size.height * (new_width / size.width);
			if ((new_height % 2) != 0) {
				new_height = new_height + 1;
			}
		}
		else {
			new_height = 640;
			new_width = size.width * (new_height / size.height);
			if ((new_width % 2) != 0) {
				new_width = new_width + 1;
			}
		}
	}
	else {
		new_width = size.width;
		new_height = size.height;
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
