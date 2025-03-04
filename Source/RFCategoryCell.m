//
//  RFCategoryCell.m
//  Snippets
//
//  Created by Manton Reece on 1/28/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import "RFCategoryCell.h"

#import "RFConstants.h"

@implementation RFCategoryCell

- (IBAction) postingCheckboxChanged:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kPostingCheckboxChangedNotification object:self userInfo:@{}];
}

@end
