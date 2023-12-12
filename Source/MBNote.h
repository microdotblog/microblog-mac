//
//  MBNote.h
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBNote : NSObject

@property (strong) NSNumber* noteID;
@property (strong) NSString* text;
@property (strong) NSDate* createdAt;
@property (strong) NSDate* updatedAt;

@end

NS_ASSUME_NONNULL_END
