//
//  RFUploadsScrollView.m
//  Snippets
//
//  Created by Manton Reece on 8/11/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFUploadsScrollView.h"

#import "RFConstants.h"

@implementation RFUploadsScrollView

- (void) awakeFromNib
{
	[super awakeFromNib];
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

- (void) paste:(id)sender
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSDictionary* options = @{ NSPasteboardURLReadingFileURLsOnlyKey: @YES };
	NSArray* urls = [pb readObjectsForClasses:@[[NSURL class]] options:options];
	NSMutableArray* paths = [NSMutableArray array];
	for (NSURL* url in urls) {
		if (url.isFileURL && (url.path.length > 0)) {
			[paths addObject:url.path];
		}
	}

	if (paths.count > 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: paths }];
		return;
	}

	NSArray* types = @[
		NSPasteboardTypePNG,
		NSPasteboardTypeTIFF
	];
	NSPasteboardType type = nil;
	NSPasteboardItem* image_item = nil;
	for (NSPasteboardType candidate_type in types) {
		for (NSPasteboardItem* item in pb.pasteboardItems) {
			if ([item.types containsObject:candidate_type]) {
				type = candidate_type;
				image_item = item;
				break;
			}
		}

		if (image_item != nil) {
			break;
		}
	}

	if (image_item != nil) {
		NSData* data = [image_item dataForType:type];
		NSImage* image = [[NSImage alloc] initWithData:data];
		if (image != nil) {
			[self handlePastedImage:image ofType:type];
			return;
		}
	}
}

- (void) handlePastedImage:(NSImage *)image ofType:(NSString *)type
{
	NSMutableArray* paths = [NSMutableArray array];
	
	// we're gonna use JPEG for TIFF data, PNG for PNG
	NSString* filename;
	NSBitmapImageFileType img_type;
	NSString* shorter_uuid = [[[NSUUID UUID].UUIDString substringToIndex:8] lowercaseString];
	if ([type isEqualToString:NSPasteboardTypePNG]) {
		filename = [NSString stringWithFormat:@"Paste-%@.png", shorter_uuid];
		img_type = NSBitmapImageFileTypePNG;
	}
	else {
		filename = [NSString stringWithFormat:@"Paste-%@.jpg", shorter_uuid];
		img_type = NSBitmapImageFileTypeJPEG;
	}
	
	// write image to temp file
	NSString* temp_folder = NSTemporaryDirectory();
	NSString* path = [temp_folder stringByAppendingPathComponent:filename];
	NSBitmapImageRep* img_rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
	NSData* d = [img_rep representationUsingType:img_type properties:@{}];
	if ([d writeToFile:path atomically:YES]) {
		[paths addObject:path];
	}
	
	// notify uploader
	[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: paths }];
}

@end
