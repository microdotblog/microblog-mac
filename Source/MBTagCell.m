//
//  MBTagCell.m
//  Micro.blog
//
//  Created by Manton Reece on 8/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBTagCell.h"

@implementation MBTagCell

- (void) setupWithName:(NSString *)tagName
{
	self.nameField.stringValue = tagName;
}

@end
