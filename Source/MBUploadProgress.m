//
//  MBUploadProgress.m
//  Micro.blog
//
//  Created by Manton Reece on 9/26/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBUploadProgress.h"

#import "RFClient.h"
#import "RFMacros.h"
#import "RFSettings.h"

const NSUInteger kUploadChunkSize = 1 * 1024 * 1024; // 1 MB chunks
static NSString* const kMBUploadProgressErrorDomain = @"MBUploadProgressErrorDomain";

@interface MBUploadProgress ()

@property (copy, nonatomic) NSString* destinationUID;

- (void) uploadNextChunkWithClient:(RFClient *)client fileHandle:(NSFileHandle *)fileHandle fileID:(NSString *)fileID destinationUID:(NSString *)destinationUID fileSize:(unsigned long long)fileSize bytesUploaded:(unsigned long long)bytesUploaded completion:(void (^)(CGFloat percent, NSError* error))handler;
- (NSError *) uploadErrorForResponse:(UUHttpResponse *)response;
- (NSError *) uploadErrorWithDescription:(NSString *)description;
- (void) failUploadWithError:(NSError *)error completion:(void (^)(CGFloat percent, NSError* handlerError))handler;
- (void) closeFileHandle;

@end

@implementation MBUploadProgress

- (void) uploadFileInBackground:(NSString *)path completion:(void (^)(CGFloat percent, NSError* error))handler
{
	RFDispatchThread(^{
		[self uploadFile:path completion:handler];
	});
}

- (void) uploadFile:(NSString *)path completion:(void (^)(CGFloat percent, NSError* error))handler
{
	if (self.cancelRequested) {
		return;
	}

	NSString* fileID = [NSString stringWithFormat:@"%06u", arc4random_uniform(900000) + 100000];
	self.currentFileID = fileID;
	self.currentFilename = [path lastPathComponent];

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media/append"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	self.destinationUID = destination_uid;

	NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	self.fileHandle = fileHandle;
	if (fileHandle == nil) {
		NSError* error = [self uploadErrorWithDescription:@"The video file could not be opened."];
		[self failUploadWithError:error completion:handler];
		return;
	}

	NSError* attributes_error = nil;
	NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&attributes_error];
	if (fileAttributes == nil) {
		NSError* error = attributes_error ?: [self uploadErrorWithDescription:@"The video file could not be read."];
		[self failUploadWithError:error completion:handler];
		return;
	}

	NSNumber* fileSizeNumber = fileAttributes[NSFileSize];
	unsigned long long fileSize = fileSizeNumber.unsignedLongLongValue;
	if (fileSize == 0) {
		NSError* error = [self uploadErrorWithDescription:@"The video file is empty."];
		[self failUploadWithError:error completion:handler];
		return;
	}

	RFDispatchMainAsync (^{
		handler(0.0, nil);
	});

	[self uploadNextChunkWithClient:client fileHandle:fileHandle fileID:fileID destinationUID:destination_uid fileSize:fileSize bytesUploaded:0 completion:handler];
}

- (void) uploadNextChunkWithClient:(RFClient *)client fileHandle:(NSFileHandle *)fileHandle fileID:(NSString *)fileID destinationUID:(NSString *)destinationUID fileSize:(unsigned long long)fileSize bytesUploaded:(unsigned long long)bytesUploaded completion:(void (^)(CGFloat percent, NSError* error))handler
{
	@autoreleasepool {
		if (self.cancelRequested) {
			[self closeFileHandle];
			return;
		}

		NSData* chunk_data = [fileHandle readDataOfLength:kUploadChunkSize];
		if (chunk_data.length == 0) {
			NSError* error = [self uploadErrorWithDescription:@"The video file ended before the upload was complete."];
			[self failUploadWithError:error completion:handler];
			return;
		}

		NSString* file_data = [chunk_data base64EncodedStringWithOptions:0];
		if (file_data == nil) {
			NSError* error = [self uploadErrorWithDescription:@"The video file could not be prepared for upload."];
			[self failUploadWithError:error completion:handler];
			return;
		}

		NSUInteger bytes_this_chunk = chunk_data.length;
		NSDictionary* params = @{
			@"file_id": fileID,
			@"file_data": file_data,
			@"mp-destination": destinationUID
		};

		NSLog(@"Upload chunk: %lu, file: %@", (unsigned long)chunk_data.length, fileID);

		[client postWithParams:params completion:^(UUHttpResponse* response) {
			if (self.cancelRequested) {
				[self closeFileHandle];
				return;
			}

			NSError* response_error = [self uploadErrorForResponse:response];
			if (response_error) {
				[self failUploadWithError:response_error completion:handler];
				return;
			}

			unsigned long long new_bytes_uploaded = bytesUploaded + bytes_this_chunk;
			CGFloat percent = (CGFloat)new_bytes_uploaded / (CGFloat)fileSize;
			RFDispatchMainAsync (^{
				if (!self.cancelRequested) {
					handler(MIN(percent, 1.0), nil);
				}
			});

			if (new_bytes_uploaded >= fileSize) {
				[self closeFileHandle];
			}
			else if (!self.cancelRequested) {
				[self uploadNextChunkWithClient:client fileHandle:fileHandle fileID:fileID destinationUID:destinationUID fileSize:fileSize bytesUploaded:new_bytes_uploaded completion:handler];
			}
		}];
	}
}

- (NSError *) uploadErrorForResponse:(UUHttpResponse *)response
{
	if (response.httpError) {
		return response.httpError;
	}

	NSInteger status_code = response.httpResponse.statusCode;
	if (status_code < 200 || status_code >= 300) {
		NSString* message = nil;
		if (status_code > 0) {
			message = [NSString stringWithFormat:@"The server returned HTTP %ld.", (long)status_code];
		}
		else {
			message = @"The upload server did not return a response.";
		}
		return [self uploadErrorWithDescription:message];
	}

	if ([response.parsedResponse isKindOfClass:[NSDictionary class]] && response.parsedResponse[@"error"]) {
		NSString* message = response.parsedResponse[@"error_description"] ?: @"The upload server rejected a video chunk.";
		return [self uploadErrorWithDescription:message];
	}

	return nil;
}

- (NSError *) uploadErrorWithDescription:(NSString *)description
{
	return [NSError errorWithDomain:kMBUploadProgressErrorDomain code:1 userInfo:@{ NSLocalizedDescriptionKey: description }];
}

- (void) failUploadWithError:(NSError *)error completion:(void (^)(CGFloat percent, NSError* handlerError))handler
{
	[self closeFileHandle];
	self.currentFileID = nil;
	self.currentFilename = nil;
	self.destinationUID = nil;

	RFDispatchMainAsync (^{
		if (!self.cancelRequested) {
			handler(0.0, error);
		}
	});
}

- (void) uploadFinished:(void (^)(BOOL))handler
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media/finished"];
	NSString* destination_uid = self.destinationUID ?: @"";
	if (self.currentFileID.length == 0 || self.currentFilename.length == 0) {
		RFDispatchMainAsync (^{
			handler(NO);
		});
		return;
	}
	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	params[@"mp-destination"] = destination_uid;
	params[@"file_id"] = self.currentFileID;
	params[@"file_name"] = self.currentFilename;

	[client postWithParams:params completion:^(UUHttpResponse* response) {
		BOOL success = ([self uploadErrorForResponse:response] == nil);

		self.currentFileID = nil;
		self.currentFilename = nil;
		self.destinationUID = nil;

		RFDispatchMainAsync (^{
			handler(success);
		});
	}];
}

- (void) cancelUpload
{
	if (self.cancelRequested) {
		return;
	}

	self.cancelRequested = YES;
	[self closeFileHandle];
	self.currentFileID = nil;
	self.currentFilename = nil;
	self.destinationUID = nil;
}

- (void) closeFileHandle
{
	if (self.fileHandle) {
		[self.fileHandle closeFile];
		self.fileHandle = nil;
	}
}

@end
