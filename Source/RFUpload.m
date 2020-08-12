//
//  RFUpload.m
//  Snippets
//
//  Created by Manton Reece on 7/14/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFUpload.h"

@implementation RFUpload

- (NSString *) filename
{
	return [self.url lastPathComponent];
}

@end
