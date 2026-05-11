//
//  RFBarExportController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/7/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import "RFExportController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RFBarExportController : RFExportController

@property (strong) NSMutableArray* posts;
@property (strong, nonatomic, nullable) NSString* destinationPath;
@property (copy, nonatomic, nullable) void (^completionHandler)(BOOL success, NSString* _Nullable path);
@property (assign, nonatomic) BOOL hasFinished;

- (void) exportToPath:(NSString *)path progress:(void (^ _Nullable)(double progress))progressHandler status:(void (^ _Nullable)(NSString* status))statusHandler completion:(void (^ _Nullable)(BOOL success, NSString* _Nullable path))completionHandler;

@end

NS_ASSUME_NONNULL_END
