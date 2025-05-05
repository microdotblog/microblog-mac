//
//  MBRenamableTextField.m
//  Micro.blog
//
//  Created by Manton Reece on 5/4/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBRenamableTextField.h"

#import "RFConstants.h"

@implementation MBRenamableTextField

- (BOOL) becomeFirstResponder
{
	// when the field is focused, show its background so it looks editable
	BOOL did_become = [super becomeFirstResponder];
	if (did_become) {
		self.drawsBackground = YES;
		self.editable = YES;
	}

	return did_become;
}

- (void) textDidEndEditing:(NSNotification *)notification
{
	[super textDidEndEditing:notification];

	self.editable = NO;
	self.drawsBackground = NO;

	[self sendRenamedNotification];
}

- (void) sendRenamedNotification
{
	NSDictionary* info = @{
		kRenamedCategoryName: self.stringValue
	};
	[[NSNotificationCenter defaultCenter] postNotificationName:kRenamedCategoryNotification object:self userInfo:info];
}

@end
