//
//  MBUploadProgress.h
//  Micro.blog
//
//  Created by Manton Reece on 9/26/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBUploadProgress : NSObject

@property (strong, nonatomic, nullable) NSString* currentFileID;

- (void) uploadFileInBackground:(NSString *)path completion:(void (^)(CGFloat))handler;
- (void) uploadFile:(NSString *)path completion:(void (^)(CGFloat))handler;
- (void) uploadFinished:(void (^)(BOOL))handler;

@end

NS_ASSUME_NONNULL_END
