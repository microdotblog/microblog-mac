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
@property (strong, nonatomic, nullable) NSString* currentFilename;
@property (assign, nonatomic) BOOL cancelRequested;
@property (strong, nonatomic, nullable) NSFileHandle* fileHandle;

- (void) uploadFileInBackground:(NSString *)path completion:(void (^)(CGFloat percent, NSError * _Nullable error))handler;
- (void) uploadFile:(NSString *)path completion:(void (^)(CGFloat percent, NSError * _Nullable error))handler;
- (void) uploadFinished:(void (^)(BOOL))handler;
- (void) cancelUpload;

@end

NS_ASSUME_NONNULL_END
