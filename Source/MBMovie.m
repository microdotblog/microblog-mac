//
//  MBMovie.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMovie.h"

@implementation MBMovie

- (NSString *) displayUsername
{
	return [NSString stringWithFormat:@"@%@", self.username];
}

@end
