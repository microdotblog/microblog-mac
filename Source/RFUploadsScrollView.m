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
	NSString* type = [pb availableTypeFromArray:@[
		NSPasteboardTypePNG,
		NSPasteboardTypeTIFF
	]];
	if (type) {
		NSData* data  = [pb dataForType:type];
		NSImage* image = [[NSImage alloc] initWithData:data];
		[self handlePastedImage:image ofType:type];
		return;
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
