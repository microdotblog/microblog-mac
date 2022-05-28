//
//  RFBookshelf.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFBookshelf.h"

@implementation RFBookshelf

- (BOOL) isEqualTo:(RFBookshelf *)bookshelf
{
	return [self.bookshelfID isEqualToNumber:bookshelf.bookshelfID];
}

@end
