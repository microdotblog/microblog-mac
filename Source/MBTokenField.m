//
//  MBTokenField.m
//  Micro.blog
//
//  Created by Manton Reece on 7/28/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBTokenField.h"

@implementation MBTokenField

- (BOOL) becomeFirstResponder
{
	BOOL responder_status = [super becomeFirstResponder];

	// unselect text after delay because AppKit is selecting all on focus
	[self performSelector:@selector(unselectTextAfterDelay) withObject:nil afterDelay:0.1];

	return responder_status;
}

- (void) unselectTextAfterDelay
{
	self.currentEditor.selectedRange = NSMakeRange (self.stringValue.length, 0);
}

@end
