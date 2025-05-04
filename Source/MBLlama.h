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

- (instancetype) initWithPath:(NSString *)modelPath;
- (NSString *) runPrompt:(NSString *)prompt;

@end

NS_ASSUME_NONNULL_END
