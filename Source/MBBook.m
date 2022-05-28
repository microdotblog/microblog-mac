//
//  MBBook.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBook.h"

@implementation MBBook

- (NSString *) microblogURL;
{
	return [NSString stringWithFormat:@"https://micro.blog/books/%@", self.isbn];
}

@end
