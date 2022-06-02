//
//  MBPhotoSelectionView.m
//  Micro.blog
//
//  Created by Manton Reece on 6/2/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBPhotoSelectionView.h"

#import "RFConstants.h"

@implementation MBPhotoSelectionView

- (void) willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kSelectPhotoCellNotification object:self userInfo:@{ kSelectPhotoCellKey: self.photoCell }];
}

@end
