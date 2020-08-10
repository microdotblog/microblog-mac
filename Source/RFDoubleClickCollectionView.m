//
//  RFDoubleClickCollectionView.m
//  Snippets
//
//  Created by Manton Reece on 8/10/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFDoubleClickCollectionView.h"

@implementation RFDoubleClickCollectionView

- (void) mouseUp:(NSEvent *)event
{
	[super mouseUp:event];
	
	if ([event clickCount] > 1) {
		id d = self.delegate;
		if (d && [d respondsToSelector:@selector(openSelectedItem)]) {
			[d performSelector:@selector(openSelectedItem)];
		}
	}
}

@end
