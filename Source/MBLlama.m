//
//  MBLlama.m
//  Micro.blog
//
//  Created by Manton Reece on 4/19/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBLlama.h"

static int const kLlamaOutputTokens = 512;

@implementation MBLlama

- (instancetype) initWithPath:(NSString *)modelPath
{
	self = [super init];
	if (self) {
		self.path = modelPath;
		[self setupLlama];
	}
	
	return self;
}

- (void) dealloc
{
	if (self.model) {
		llama_model_free(self.model);
	}
}

- (void) setupLlama
{
	// hardcoded settings
	const char* model_path = [self.path cStringUsingEncoding:NSUTF8StringEncoding];
	int ngl = 99;
	
	// load dynamic backends
	ggml_backend_load_all();
	
	// initialize the model
	struct llama_model_params model_params = llama_model_default_params();
	model_params.n_gpu_layers = ngl;
	
	self.model = llama_model_load_from_file(model_path, model_params);
	if (!self.model) {
		fprintf(stderr, "%s: error: unable to load model\n", __func__);
	}
}

- (NSString *) runPrompt:(NSString *)prompt
{
	if (self.model == NULL) {
		return nil;
	}
	
	NSMutableString* answer = [[NSMutableString alloc] init];

	int n_predict = kLlamaOutputTokens;
	const struct llama_vocab *vocab = llama_model_get_vocab(self.model);
	
	// tokenize the prompt
	int n_prompt = -llama_tokenize(vocab, [prompt cStringUsingEncoding:NSUTF8StringEncoding], (int)prompt.length, NULL, 0, true, true);
	if (n_prompt <= 0) {
		fprintf(stderr, "%s: error: tokenization failed\n", __func__);
		return nil;
	}
	
	llama_token *prompt_tokens = malloc(n_prompt * sizeof(llama_token));
	if (!prompt_tokens) {
		fprintf(stderr, "error: out of memory\n");
		return nil;
	}
	if (llama_tokenize(vocab, [prompt cStringUsingEncoding:NSUTF8StringEncoding], (int)prompt.length, prompt_tokens, n_prompt, true, true) < 0) {
		fprintf(stderr, "%s: error: failed to tokenize the prompt\n", __func__);
		free(prompt_tokens);
		return nil;
	}
	
	// initialize the context
	struct llama_context_params ctx_params = llama_context_default_params();
	ctx_params.n_ctx   = n_prompt + n_predict - 1;
	ctx_params.n_batch = n_prompt;
	ctx_params.no_perf = false;
	
	struct llama_context *ctx = llama_init_from_model(self.model, ctx_params);
	if (!ctx) {
		fprintf(stderr, "%s: error: failed to create llama_context\n", __func__);
		free(prompt_tokens);
		return nil;
	}
	
	// initialize the sampler
	struct llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
	sparams.no_perf = false;
	struct llama_sampler *smpl = llama_sampler_chain_init(sparams);
	
	llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.0));
	llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
		
	llama_batch batch = llama_batch_get_one(prompt_tokens, n_prompt);
	
	// main generation loop
	uint64_t t_start = ggml_time_us();
	int n_decoded = 0;
	llama_token new_token;
	
	while (n_decoded + (int)batch.n_tokens < n_prompt + n_predict) {
		if (llama_decode(ctx, batch)) {
			fprintf(stderr, "%s: failed to eval\n", __func__);
			break;
		}
		n_decoded += batch.n_tokens;
		
		new_token = llama_sampler_sample(smpl, ctx, -1);
		if (llama_vocab_is_eog(vocab, new_token)) break;
		
		char buf[128];
		int len = llama_token_to_piece(vocab, new_token, buf, sizeof(buf), 0, true);
		if (len < 0) {
			fprintf(stderr, "%s: error: failed to convert token to piece\n", __func__);
			break;
		}
		[answer appendFormat:@"%.*s", len, buf];
//		fflush(stdout);
		
		batch = llama_batch_get_one(&new_token, 1);
	}
	
	uint64_t t_end = ggml_time_us();
	fprintf(stderr, "%s: decoded %d tokens in %.2f s, speed: %.2f t/s\n",
			__func__, n_decoded,
			(t_end - t_start) / 1e6f,
			n_decoded / ((t_end - t_start) / 1e6f));
	
//	llama_perf_sampler_print(smpl);
//	llama_perf_context_print(ctx);
	
	// cleanup
	free(prompt_tokens);
	llama_sampler_free(smpl);
	llama_free(ctx);
	
	return answer;
}

@end
