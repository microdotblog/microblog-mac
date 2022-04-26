//
//  RFClient.m
//  Snippets
//
//  Created by Manton Reece on 8/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFClient.h"

#import "NSString+Extras.h"
#import "RFSettings.h"
#import "SAMKeychain.h"

//static NSString* const kServerSchemeAndHostname = @"http://localhost:3000";
static NSString* const kServerSchemeAndHostname = @"https://micro.blog";

@implementation RFClient

- (instancetype) initWithPath:(NSString *)path
{
	self = [super init];
	if (self) {
		self.path = path;
		self.url = [NSString stringWithFormat:@"%@%@", kServerSchemeAndHostname, self.path];
	}
	
	return self;
}

- (instancetype) initWithFormat:(NSString *)path, ...
{
	self = [super init];
	if (self) {
		va_list args;
		va_start (args, path);
		self.path = [[NSString alloc] initWithFormat:path arguments:args];
		self.url = [NSString stringWithFormat:@"%@%@", kServerSchemeAndHostname, self.path];
	}
	
	return self;
}

- (void) setupRequest:(UUHttpRequest *)request
{
	NSMutableDictionary* headers = [request.headerFields mutableCopy];
	if (headers == nil) {
		headers = [NSMutableDictionary dictionary];
	}

	NSString* username = [RFSettings stringForKey:kAccountUsername];
	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];
	if (token) {
		[headers setObject:[NSString stringWithFormat:@"Token %@", token] forKey:@"Authorization"];
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

#pragma mark -

- (UUHttpRequest *) postWithParams:(NSDictionary *)params completion:(void (^)(UUHttpResponse* response))handler
{
	NSMutableString* body_s = [NSMutableString string];
	
	NSArray* all_keys = [params allKeys];
	for (int i = 0; i < [all_keys count]; i++) {
		NSString* key = [all_keys objectAtIndex:i];
		BOOL added_param = NO;
		
		if ([params[key] isKindOfClass:[NSString class]]) {
			NSString* val = params[key];
			NSString* val_encoded = [val rf_urlEncoded];
			[body_s appendFormat:@"%@=%@", key, val_encoded];
			added_param = YES;
		}
		else if ([params[key] isKindOfClass:[NSArray class]]) {
			NSArray* array_values = params[key];
			for (int array_i = 0; array_i < [array_values count]; array_i++) {
				NSString* val = [array_values objectAtIndex:array_i];
				NSString* val_encoded = [val rf_urlEncoded];
				[body_s appendFormat:@"%@=%@", key, val_encoded];
				if (array_i != ([array_values count] - 1)) {
					[body_s appendString:@"&"];
				}
				added_param = YES;
			}
		}

		if (added_param && (i != ([all_keys count] - 1))) {
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

- (UUHttpRequest *) putWithObject:(id)object completion:(void (^)(UUHttpResponse* response))handler
{
	NSData* d;
	if (object) {
		d = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
	}
	else {
		d = [NSData data];
	}

	UUHttpRequest* request = [UUHttpRequest putRequest:self.url queryArguments:nil body:d contentType:@"application/json"];
	[self setupRequest:request];

	return [UUHttpSession executeRequest:request completionHandler:handler];
}

- (UUHttpRequest *) uploadImageData:(NSData *)imageData named:(NSString *)imageName httpMethod:(NSString *)method queryArguments:(NSDictionary *)args isVideo:(BOOL)isVideo isGIF:(BOOL)isGIF isPNG:(BOOL)isPNG completion:(void (^)(UUHttpResponse* response))handler
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
		NSString* filename;
		if (isVideo) {
			filename = @"video.mov";
		}
		else if (isGIF) {
			filename = @"image.gif";
		}
		else if (isPNG) {
			filename = @"image.png";
		}
		else {
			filename = @"image.jpg";
		}

		[d appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", imageName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
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

- (UUHttpRequest *) uploadFileData:(NSData *)imageData named:(NSString *)imageName filename:(NSString *)filename contentType:(NSString *)contentType httpMethod:(NSString *)method queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
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
		[d appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", imageName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
		[d appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", contentType] dataUsingEncoding:NSUTF8StringEncoding]];
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

#pragma mark -

- (UUHttpRequest *) deleteWithObject:(id)object completion:(void (^)(UUHttpResponse* response))handler
{
	return [self deleteWithObject:object queryArguments:nil completion:handler];
}

- (UUHttpRequest *) deleteWithObject:(id)object queryArguments:(NSDictionary *)args completion:(void (^)(UUHttpResponse* response))handler
{
	NSData* d;
	if (object) {
		d = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
	}
	else {
		d = [NSData data];
	}

	UUHttpRequest* request = [UUHttpRequest deleteRequest:self.url queryArguments:args body:d contentType:@"application/json"];
	[self setupRequest:request];

	return [UUHttpSession executeRequest:request completionHandler:handler];
}

@end
