//
//  MBHighlightCell.m
//  Micro.blog
//
//  Created by Manton Reece on 7/25/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBHighlightCell.h"

#import "MBHighlight.h"

@implementation MBHighlightCell

- (void) setupWithHighlight:(MBHighlight *)highlight
{
	self.highlight = highlight;
	
	[self.selectionTextField setStringValue:self.highlight.selectionText];
}

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
}

@end
