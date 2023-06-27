//
//  RFBookshelf.h
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFBookshelf : NSObject

@property (strong) NSNumber* bookshelfID;
@property (strong) NSString* title;
@property (strong) NSNumber* booksCount;
@property (strong) NSString* type;

- (BOOL) isEqualToBookshelf:(RFBookshelf *)bookshelf;
- (BOOL) isLibrary;
+ (BOOL) isSameBooks:(NSArray *)books asBooks:(NSArray *)otherBooks;

@end

NS_ASSUME_NONNULL_END
