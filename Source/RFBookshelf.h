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

@end

NS_ASSUME_NONNULL_END
