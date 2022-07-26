//
//  MBDisableDragImageView.m
//  Micro.blog
//
//  Created by Manton Reece on 7/26/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBDisableDragImageView.h"

@implementation MBDisableDragImageView

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
