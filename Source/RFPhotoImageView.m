//
//  RFPhotoImageView.m
//  Snippets
//
//  Created by Manton Reece on 8/11/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFPhotoImageView.h"

@implementation RFPhotoImageView

- (void) awakeFromNib
{
	[super awakeFromNib];
	
	[self unregisterDraggedTypes];
}

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
	return NSDragOperationNone;
}

@end
