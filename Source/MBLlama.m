//
//  MBLlama.m
//  Micro.blog
//
//  Created by Manton Reece on 4/19/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBLlama.h"

#include "llama.h"

@implementation MBLlama

- (instancetype) init
{
	self = [super init];
	if (self) {
		[self setupLlama];
	}
	
	return self;
}

- (void) setupLlama
{
	struct llama_model_params params = llama_model_default_params();
	params.vocab_only   = false;
	params.use_mmap     = true;
	params.use_mlock    = false;

	struct llama_model* model = llama_model_load_from_file("path/to/model.gguf", params);
	if (!model) {
		fprintf(stderr, "error: failed to load model\n");
	}
}

@end
