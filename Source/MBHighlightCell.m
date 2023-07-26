//
//  MBHighlightCell.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightCell.h"

#import "MBHighlight.h"
#import "UUDate.h"

@implementation MBHighlightCell

- (void) setupWithHighlight:(MBHighlight *)highlight
{
	self.highlight = highlight;
	
	self.selectionTextField.stringValue = highlight.selectionText;
	
	NSURL* url = [NSURL URLWithString:highlight.url];
	NSString* s = [NSString stringWithFormat:@"%@: %@", url.host, highlight.title];
	self.titleField.stringValue = s;
	
	NSString* date_s = [highlight.createdAt uuIso8601DateString];
	self.dateField.stringValue = date_s;
}

- (void) drawBackgroundInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	[[NSColor colorNamed:@"color_highlight_background"] set];
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
