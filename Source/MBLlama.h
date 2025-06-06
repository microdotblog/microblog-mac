//
//  MBLlama.h
//  Micro.blog
//
//  Created by Manton Reece on 4/19/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "llama.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBLlama : NSObject

@property (assign, nonatomic) struct llama_model* model;
@property (strong, nonatomic) NSString* path;

- (instancetype) initWithModelPath:(NSString *)modelPath mmprojPath:(NSString *)mmprojPath;
- (NSString *) runPrompt:(NSString *)prompt;
- (NSString *) runPrompt:(NSString *)prompt withImage:(nullable NSString *)imagePath;

@end

NS_ASSUME_NONNULL_END
