//
//  MBBook.h
//  Micro.blog
//
//  Created by Manton Reece on 5/18/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBBook : NSObject

@property (strong) NSNumber* bookID;
@property (strong) NSString* title;
@property (strong) NSString* coverURL;
@property (strong) NSImage* coverImage;

@end

NS_ASSUME_NONNULL_END
