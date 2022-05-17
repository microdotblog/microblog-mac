//
//  RFRepliesController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/17/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFRepliesController.h"

@implementation RFRepliesController

- (id) init
{
	self = [super initWithNibName:@"Replies" bundle:nil];
	if (self) {
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self fetchReplies];
}

- (void) fetchReplies
{
}

@end
