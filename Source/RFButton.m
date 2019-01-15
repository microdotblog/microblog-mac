//
//  RFButton.m
//  Snippets
//
//  Created by Manton Reece on 1/15/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFButton.h"

@implementation RFButton

- (void) awakeFromNib
{
//	NSMutableAttributedString* attr_s = [[NSMutableAttributedString alloc] initWithString:self.title];
//	NSUInteger len = [attr_s length];
//	NSRange range = NSMakeRange (0, len);
//	[attr_s addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:range];
//	[attr_s fixAttributesInRange:range];
//	[self setAttributedTitle:attr_s];
}

@end

@implementation RFButtonCell

- (NSRect) drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
	NSMutableAttributedString* attr_s = [[NSMutableAttributedString alloc] initWithAttributedString:title];
	NSUInteger len = [attr_s length];
	NSRange range = NSMakeRange (0, len);
	[attr_s addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:range];
	[attr_s fixAttributesInRange:range];

	return [super drawTitle:attr_s withFrame:frame inView:controlView];
}

@end
