//
//  RFUpload.h
//  Snippets
//
//  Created by Manton Reece on 7/14/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFUpload : NSObject

@property (strong) NSImage* cachedImage;
@property (strong) NSString* url;
@property (assign) NSInteger width;
@property (assign) NSInteger height;
@property (strong) NSDate* createdAt;

@end

NS_ASSUME_NONNULL_END
