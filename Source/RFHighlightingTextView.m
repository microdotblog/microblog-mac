//
//  RFHighlightingTextView.m
//  Snippets
//
//  Created by Manton Reece on 10/10/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFHighlightingTextView.h"

#import "RFConstants.h"

@implementation RFHighlightingTextView

- (BOOL) shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
{
	self.restoredSelection = NSMakeRange (affectedCharRange.location + replacementString.length, 0);

	return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
}

- (void) didChangeText
{
	[super didChangeText];
	
	self.selectedRange = self.restoredSelection;
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

- (void) draggingExited:(nullable id <NSDraggingInfo>)sender
{
	[super draggingExited:sender];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:kAttachFilesNotification object:self userInfo:@{ kAttachFilesPathsKey: paths }];

		return YES;
	}
	else {
		return [super performDragOperation:sender];
	}
}

@end
