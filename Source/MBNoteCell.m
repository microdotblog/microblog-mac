//
//  MBNoteCell.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNoteCell.h"

#import "MBNote.h"

@implementation MBNoteCell

- (void) setupWithNote:(MBNote *)note
{
	if (note.isShared) {
		self.sharedView.hidden = NO;
		self.sharedHeightConstraint.constant = 28;
	}
	else {
		self.sharedView.hidden = YES;
		self.sharedHeightConstraint.constant = 0;
	}
	
	NSString* s = note.text;
	if (s.length > 100) {
		s = [s substringToIndex:100];
		s = [s stringByAppendingString:@"..."];
	}
	
	[self.textView setStringValue:s];
}

- (void) drawBackgroundInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	[self.backgroundColor set];
	NSRectFill (r);
}

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	if ([self.superview isKindOfClass:[NSTableView class]]) {
		NSTableView* table = (NSTableView *)self.superview;
		if (![table.window isKeyWindow]) {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
		else if (table.window.firstResponder == table) {
			[[NSColor selectedContentBackgroundColor] set];
		}
		else {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
	}
	
	NSRectFill (r);
}

@end
