//
//  MBCrosspostCell.m
//  Micro.blog
//
//  Created by Manton Reece on 2/19/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBCrosspostCell.h"

#import "RFConstants.h"

@implementation MBCrosspostCell

- (IBAction) postingCheckboxChanged:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPostingCheckboxChangedNotification object:self userInfo:@{}];
}

@end
