//
//  RFDoubleClickCollectionView.m
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFDoubleClickCollectionView.h"

#import "RFAllUploadsController.h"
#import "RFConstants.h"
#import "RFSettings.h"

@implementation RFDoubleClickCollectionView

- (void) mouseUp:(NSEvent *)event
{
	[super mouseUp:event];
	
	if ([event clickCount] > 1) {
		id d = self.delegate;
		if (d && [d respondsToSelector:@selector(openSelectedItem)]) {
			[d performSelector:@selector(openSelectedItem)];
		}
	}
}

- (void) keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@"\r"]) {
		if ([self.delegate respondsToSelector:@selector(openSelectedItem)]) {
			[self.delegate performSelector:@selector(openSelectedItem)];
		}
	}
	else {
		[super keyDown:event];
	}
}

#pragma mark -

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	if ([pb.types containsObject:NSPasteboardTypeFileURL]) {
		return NSDragOperationCopy;
	}
	else {
		return [super draggingEntered:sender];
	}
}

- (NSDragOperation) draggingUpdated:(id<NSDraggingInfo>)sender
{
	return NSDragOperationCopy;
}

- (void) draggingExited:(nullable id <NSDraggingInfo>)sender
{
}

- (void) draggingEnded:(id<NSDraggingInfo>)sender
{
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	if ([pb.types containsObject:NSPasteboardTypeFileURL]) {
		return YES;
	}
	else {
		return [super prepareForDragOperation:sender];
	}
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];

	NSArray* types = [NSFilePromiseReceiver readableDraggedTypes];
	NSPasteboardType best_type = [pb availableTypeFromArray:types];
	if (best_type != nil) {
		// temp folder for saving files
		NSString* temp_filename = [NSString stringWithFormat:@"Micro.blog-%@", [[NSUUID UUID] UUIDString]];
		NSString* temp_folder = [NSTemporaryDirectory() stringByAppendingPathComponent:temp_filename];
		[RFSettings addTemporaryFolder:temp_folder];
		[[NSFileManager defaultManager] createDirectoryAtPath:temp_folder withIntermediateDirectories:YES attributes:nil error:NULL];
		NSURL* dest_url = [NSURL fileURLWithPath:temp_folder];

		// get promised files
		NSArray* promises = [pb readObjectsForClasses:@[[NSFilePromiseReceiver class]] options:nil];

		// collect all promised file paths before notifying
		NSMutableArray* paths = [NSMutableArray array];
		dispatch_group_t group = dispatch_group_create();
		for (NSFilePromiseReceiver *promise in promises) {
			dispatch_group_enter(group);
			NSOperationQueue *queue = [NSOperationQueue mainQueue];
			[promise receivePromisedFilesAtDestination:dest_url options:@{} operationQueue:queue reader:^(NSURL *file_url, NSError *error) {
				if (file_url) {
					@synchronized(paths) {
						[paths addObject:file_url.path];
					}
				}
				dispatch_group_leave(group);
			}];
		}
		
		// notify only after we have everything
		dispatch_group_notify(group, dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: paths }];
		});
		return YES;
	}
	else if ([pb.types containsObject:NSPasteboardTypeFileURL]) {
		NSArray* file_urls = [pb readObjectsForClasses:@[ NSURL.class ] options:@{ NSPasteboardURLReadingFileURLsOnlyKey: @YES }];
		NSMutableArray* paths = [NSMutableArray array];
		for (NSURL* url in file_urls) {
			[paths addObject:url.path];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: paths }];
		return YES;
	}
	else {
		return [super performDragOperation:sender];
	}
}

@end
