//
//  MBMovie.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBMovie : NSObject

@property (strong, nonatomic) NSString* title;
@property (strong, nonatomic) NSString* username;
@property (strong, nonatomic) NSString* posterURL;
@property (strong, nonatomic) NSImage* posterImage;
@property (strong, nonatomic) NSString* year;
@property (strong, nonatomic) NSString* director;

- (NSString *) displayUsername;

@end

NS_ASSUME_NONNULL_END
