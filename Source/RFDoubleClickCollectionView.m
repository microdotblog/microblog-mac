//
//  RFDoubleClickCollectionView.m
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFDoubleClickCollectionView.h"

#import "RFConstants.h"

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

#pragma mark -

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	if ([pb.types containsObject:NSFilenamesPboardType]) {
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
	if ([pb.types containsObject:NSFilenamesPboardType]) {
		return YES;
	}
	else {
		return [super prepareForDragOperation:sender];
	}
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	if ([pb.types containsObject:NSFilenamesPboardType]) {
		NSArray* paths = [pb propertyListForType:NSFilenamesPboardType];
		[[NSNotificationCenter defaultCenter] postNotificationName:kUploadFilesNotification object:self userInfo:@{ kUploadFilesPathsKey: paths }];

		return YES;
	}
	else {
		return [super performDragOperation:sender];
	}
}

@end
