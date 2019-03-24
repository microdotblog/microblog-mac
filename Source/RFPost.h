//
//  RFPost.h
//  Snippets
//
//  Created by Manton Reece on 3/24/19.
//  Copyright © 2019 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPost : NSObject

@property (strong) NSNumber* postID;
@property (strong) NSString* title;
@property (strong) NSString* text;
@property (strong) NSDate* postedAt;
@property (assign) BOOL isDraft;

@end

NS_ASSUME_NONNULL_END
