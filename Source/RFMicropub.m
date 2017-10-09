//
//  RFMicropub.m
//  Micro.blog
//
//  Created by Manton Reece on 4/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFMicropub.h"

#import "NSString+Extras.h"
#import "SSKeychain.h"

@implementation RFMicropub

- (instancetype) initWithURL:(NSString *)url;
{
	self = [super init];
	if (self) {
		self.url = url;
	}
	
	return self;
}

- (void) setupRequest:(UUHttpRequest *)request
{
	NSMutableDictionary* headers = [request.headerFields mutableCopy];
	if (headers == nil) {
		headers = [NSMutableDictionary dictionary];
	}
	
	[headers setObject:@"application/json" forKey:@"Accept"];
	
	NSString* token = [SSKeychain passwordForService:@"ExternalMicropub" account:@"default"];
	if (token) {
		NSString* s = [NSString stringWithFormat:@"Bearer %@", token];
		[headers setObject:s forKey:@"Authorization"];
	}
	
	request.headerFields = headers;
}

#pragma mark -

- (UUHttpRequest *) getWithQueryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	UUHttpRequest* request = [UUHttpRequest getRequest:self.url queryArguments:args];
	[self setupRequest:request];
	
	return [UUHttpSession executeRequest:request completionHandler:handler];
}

- (UUHttpRequest *) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse* response))handler
{
	NSMutableString* body_s = [NSMutableString string];
	
	NSArray* all_keys = [params allKeys];
	for (int i = 0; i < [all_keys count]; i++) {
		NSString* key = [all_keys objectAtIndex:i];
		
		if ([params[key] isKindOfClass:[NSString class]]) {
			NSString* val = params[key];
			NSString* val_encoded = [val rf_urlEncoded];
			[body_s appendFormat:@"%@=%@", key, val_encoded];
		}
		else if ([params[key] isKindOfClass:[NSArray class]]) {
			for (NSString* val in params[key]) {
				NSString* val_encoded = [val rf_urlEncoded];
				[body_s appendFormat:@"%@=%@", key, val_encoded];
				if ([params[key] lastObject] != val) {
					[body_s appendString:@"&"];
				}
			}
		}

		if (i != ([all_keys count] - 1)) {
			[body_s appendString:@"&"];
		}
	}
	
	NSData* d = [body_s dataUsingEncoding:NSUTF8StringEncoding];
	UUHttpRequest* request = [UUHttpRequest postRequest:self.url queryArguments:nil body:d contentType:@"application/x-www-form-urlencoded"];
	[self setupRequest:request];

	return [UUHttpSession executeRequest:request completionHandler:handler];
}

- (UUHttpRequest *) postWithObject:(id)object completion:(void (^)(UUHttpResponse* response))handler
{
	return [self postWithObject:object queryArguments:nil completion:handler];
}

- (UUHttpRequest *) postWithObject:(id)object queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	NSData* d;
	if (object) {
		d = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
	}
	else {
		d = [NSData data];
	}

	UUHttpRequest* request = [UUHttpRequest postRequest:self.url queryArguments:args body:d contentType:@"application/json"];
	[self setupRequest:request];

	return [UUHttpSession executeRequest:request completionHandler:handler];
}

#pragma mark -

- (UUHttpRequest *) uploadImageData:(NSData *)imageData named:(NSString *)imageName httpMethod:(NSString *)method queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	NSString* boundary = [[NSProcessInfo processInfo] globallyUniqueString];
	NSMutableData* d = [NSMutableData data];

	for (NSString* k in [args allKeys]) {
		NSString* val = [args objectForKey:k];
		[d appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", k] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[[NSString stringWithFormat:@"%@\r\n", val] dataUsingEncoding:NSUTF8StringEncoding]];
	}

	if (imageData) {
		[d appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image.jpg\"\r\n", imageName] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:imageData];
		[d appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	}

	[d appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	UUHttpRequest* request;
	
	if ([[method uppercaseString] isEqualToString:@"PUT"]) {
		request = [UUHttpRequest putRequest:self.url queryArguments:nil body:d contentType:@"application/json"];
	}
	else {
		request = [UUHttpRequest postRequest:self.url queryArguments:nil body:d contentType:@"application/json"];
	}
	[self setupRequest:request];
	
	NSString* content_type = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	NSMutableDictionary* headers = [request.headerFields mutableCopy];
	[headers setObject:content_type forKey:@"Content-Type"];
	request.headerFields = headers;

	return [UUHttpSession executeRequest:request completionHandler:handler];
}

@end
