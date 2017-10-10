//
//  RFHighlightingTextView.m
//  Snippets
//
//  Created by Manton Reece on 10/10/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFHighlightingTextView.h"

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

@end
