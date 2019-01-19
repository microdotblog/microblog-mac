//
//  RFHighlightingTextView.m
//  Snippets
//
//  Created by Manton Reece on 10/10/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFHighlightingTextView.h"
#import "RFAutoCompleteCache.h"
#import "RFConstants.h"

@implementation RFHighlightingTextView

- (BOOL) shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
{
	self.restoredSelection = NSMakeRange (affectedCharRange.location + replacementString.length, 0);
	
	if (replacementString.length == 1)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self findAutocomplete:affectedCharRange newString:replacementString];
		});
	}

	//	NSLog (@"replacement = %@", replacementString);
	return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
}

- (void) didChangeText
{
	[super didChangeText];
	
	self.selectedRange = self.restoredSelection;
}

- (void) insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)isFinal
{
	if (isFinal && (movement == NSTextMovementReturn)) {
		NSString* s = [NSString stringWithFormat:@"%@ ", word];
		[super insertCompletion:s forPartialWordRange:charRange movement:movement isFinal:isFinal];
	}
}

- (NSPasteboardType) preferredPasteboardTypeFromArray:(NSArray<NSPasteboardType> *)availableTypes
                          restrictedToTypesFromArray:(NSArray<NSPasteboardType> *)allowedTypes
{
	if ([availableTypes containsObject:NSPasteboardTypeString]) {
		return NSPasteboardTypeString;
	}
	else {
		return [super preferredPasteboardTypeFromArray:availableTypes restrictedToTypesFromArray:allowedTypes];
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

- (void) findAutocomplete:(NSRange)range newString:(NSString*)incomingString{
	NSMutableString* username = [NSMutableString string];
	
	// work backwards from current point
	BOOL is_found = NO;
	NSString* s = self.string;
	for (NSInteger i = range.location; i >= 0; i--) {
		if (s.length > i) {
			unichar c = [s characterAtIndex:i];
			unichar prev_c = '\0';
			if (i > 0) {
				prev_c = [s characterAtIndex:i - 1];
			}
			
			NSString* new_s = [NSString stringWithFormat:@"%C", c];
			[username insertString:new_s atIndex:0];
			
			if (c == ' ') {
				break;
			}
			else if (c == '@') {
				if (!isalnum (prev_c)) { // make sure we're not in an email address
					is_found = YES;
					break;
				}
			}
		}
	}
	
	if (is_found && (username.length > 0)) {
		[username appendString:incomingString];
		
		[RFAutoCompleteCache findAutoCompleteFor:username completion:^(NSArray * _Nonnull results)
		 {
			 dispatch_async(dispatch_get_main_queue(), ^
							{
								NSDictionary* dictionary = @{ @"string" : username, @"array" : results };
								[[NSNotificationCenter defaultCenter] postNotificationName:kRFFoundUserAutoCompleteNotification object:dictionary];
							});
			 
		 }];
	}
	else
	{
		dispatch_async(dispatch_get_main_queue(), ^
					   {
						   NSDictionary* dictionary = @{ @"string" : @"", @"array" : @[] };
						   [[NSNotificationCenter defaultCenter] postNotificationName:kRFFoundUserAutoCompleteNotification object:dictionary];
					   });
	}

}

@end
