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

	[self updateTextColorsForSelected:self.isSelected];
}

- (void) drawBackgroundInRect:(NSRect)dirtyRect
{
	NSRect r = self.bounds;
	[[NSColor colorNamed:@"color_highlight_row_background"] set];
	NSRectFill (r);
}

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	NSColor* background_color = [NSColor selectedContentBackgroundColor];
	if ([self.superview isKindOfClass:[NSTableView class]]) {
		NSTableView* table = (NSTableView *)self.superview;
		if (![table.window isKeyWindow]) {
			background_color = [NSColor colorNamed:@"color_row_unfocused_selection"];
		}
		else if (table.window.firstResponder == table) {
			background_color = [NSColor selectedContentBackgroundColor];
		}
		else {
			background_color = [NSColor colorNamed:@"color_row_unfocused_selection"];
		}
	}

	[self updateTextColorsForSelected:YES];
	[background_color set];
	NSRectFill (self.bounds);
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	[self updateTextColorsForSelected:selected];
}

- (void) updateTextColorsForSelected:(BOOL)selected
{
	if (selected) {
		self.selectionTextField.textColor = [NSColor colorNamed:@"color_date_text_selected"];
		self.titleField.textColor = [NSColor colorNamed:@"color_date_text_selected"];
		self.dateField.textColor = [NSColor colorNamed:@"color_date_text_selected"];
	}
	else {
		self.selectionTextField.textColor = [NSColor colorNamed:@"color_highlight_text"];
		self.titleField.textColor = [NSColor colorNamed:@"color_date_text"];
		self.dateField.textColor = [NSColor colorNamed:@"color_date_text"];
	}
}

@end
