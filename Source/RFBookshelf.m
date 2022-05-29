//
//  RFBookshelf.m
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "RFBookshelf.h"

#import "MBBook.h"

@implementation RFBookshelf

- (BOOL) isEqualTo:(RFBookshelf *)bookshelf
{
	return [self.bookshelfID isEqualToNumber:bookshelf.bookshelfID];
}

+ (BOOL) isSameBooks:(NSArray *)books asBooks:(NSArray *)otherBooks
{
	NSMutableSet* isbns1 = [NSMutableSet set];
	NSMutableSet* isbns2 = [NSMutableSet set];
	
	for (MBBook* b in books) {
		[isbns1 addObject:b.isbn];
	}

	for (MBBook* b in otherBooks) {
		[isbns2 addObject:b.isbn];
	}
	
	return [isbns1 isEqualTo:isbns2];
}

@end
