//
//  RFXMLRPCRequest.m
//  Snippets
//
//  Created by Manton Reece on 8/30/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFXMLRPCRequest.h"

#import "RFXMLRSDParser.h"
#import "UUDate.h"

@implementation RFBoolean

- (instancetype) initWithBool:(BOOL)value
{
	self = [super init];
	if (self) {
		self.boolValue = value;
	}
	
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%d", self.boolValue];
}

@end

#pragma mark -

@implementation RFXMLRPCRequest

- (instancetype) initWithURL:(NSString *)url
{
	self = [super init];
	if (self) {
		self.url = url;
	}
	
	return self;
}

- (UUHttpRequest *) getPath:(NSString *)path completion:(void (^)(UUHttpResponse* response))handler
{
	NSString* full_url = [self.url stringByAppendingPathComponent:path];

	UUHttpRequest* request = [UUHttpRequest getRequest:full_url queryArguments:nil];
	return [UUHttpSession executeRequest:request completionHandler:handler];
}

- (NSString *) escapeParam:(NSString *)value
{
	NSString* s = value;
	
	s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
	s = [s stringByReplacingOccurrencesOfString:@"'" withString:@"&#x27;"];
	s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	
	return s;
}

- (void) appendParam:(id)param toString:(NSMutableString *)requestString
{
	if ([param isKindOfClass:[RFBoolean class]]) {
		[requestString appendFormat:@"<value><boolean>%@</boolean></value>", param];
	}
	else if ([param isKindOfClass:[NSNumber class]]) {
		[requestString appendFormat:@"<value><int>%@</int></value>", param];
	}
	else if ([param isKindOfClass:[NSDate class]]) {
		NSTimeZone* utcTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
		NSString* iso8601 = [param uuStringFromDate:@"yyyyMMdd'T'HH:mm:ssZ" timeZone:utcTimeZone];
		[requestString appendFormat:@"<value><dateTime.iso8601>%@</dateTime.iso8601></value>", iso8601];
	}
	else if ([param isKindOfClass:[NSString class]]) {
		[requestString appendFormat:@"<value><string>%@</string></value>", [self escapeParam:param]];
	}
	else if ([param isKindOfClass:[NSDictionary class]]) {
		[requestString appendString:@"<value><struct>"];
		NSArray* keys = [param allKeys];
		for (NSString* k in keys) {
			id val = [param objectForKey:k];
			[requestString appendString:@"<member>"];
			[requestString appendFormat:@"<name>%@</name>", k];
			[self appendParam:val toString:requestString];
			[requestString appendString:@"</member>"];
		}
		[requestString appendString:@"</struct></value>"];
	}
	else if ([param isKindOfClass:[NSArray class]]) {
		[requestString appendString:@"<value><array><data>"];
		for (id val in param) {
			[self appendParam:val toString:requestString];
		}
		[requestString appendString:@"</data></array></value>"];
	}
	else if ([param isKindOfClass:[NSData class]]) {
		NSData* d = param;
		[requestString appendFormat:@"<value><base64>%@</base64></value>", [d base64EncodedStringWithOptions:0]];
	}
}

- (UUHttpRequest *) sendMethod:(NSString *)method params:(NSArray *)params completion:(void (^)(UUHttpResponse* response))handler
{
	NSMutableString* s = [[NSMutableString alloc] init];
	[s appendString:@"<?xml version=\"1.0\"?>"];
	[s appendFormat:@"<methodCall><methodName>%@</methodName>", method];
	[s appendString:@"<params>"];

	for (id param in params) {
		[s appendString:@"<param>"];
		[self appendParam:param toString:s];
		[s appendString:@"</param>"];
	}

	[s appendString:@"</params>"];
	[s appendString:@"</methodCall>"];

	NSData* d = [s dataUsingEncoding:NSUTF8StringEncoding];
	UUHttpRequest* request = [UUHttpRequest postRequest:self.url queryArguments:nil body:d contentType:@"text/xml"];
	return [UUHttpSession executeRequest:request completionHandler:handler];
}

- (void) processRSD:(NSArray *)dictionaryEndpoints withCompletion:(void (^)(NSString* xmlrpcEndpointURL, NSString* blogID))handler
{
	NSString* best_endpoint_url = nil;
	NSString* blog_id = nil;
	
	for (NSDictionary* api in dictionaryEndpoints) {
		if ([api[@"name"] isEqualToString:@"Blogger"]) {
			blog_id = api[@"blogID"];
			best_endpoint_url = api[@"apiLink"];
			break;
		}
	}
	
	handler (best_endpoint_url, blog_id);
}

- (void) discoverEndpointWithCompletion:(void (^)(NSString* xmlrpcEndpointURL, NSString* blogID))handler
{
	[self getPath:@"" completion:^(UUHttpResponse* response) {
		RFXMLRSDParser* rsd = [RFXMLRSDParser parsedResponseFromData:response.rawResponse];
		if ([rsd.foundEndpoints count] > 0) {
			[self processRSD:rsd.foundEndpoints withCompletion:handler];
		}
		else {
			handler (nil, nil);
		}
	}];
}

@end
