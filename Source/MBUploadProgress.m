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

@implementation MBUploadProgress

- (void) uploadFileInBackground:(NSString *)path completion:(void (^)(CGFloat))handler
{
	RFDispatchThread(^{
		[self uploadFile:path completion:handler];
	});
}

- (void) uploadFile:(NSString *)path completion:(void (^)(CGFloat))handler
{
	NSString* fileID = [NSString stringWithFormat:@"%06u", arc4random_uniform(900000) + 100000];
	self.currentFileID = fileID;
	self.currentFilename = [path lastPathComponent];

	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media/append"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}

	NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	if (fileHandle == nil) {
		self.currentFileID = nil;
		self.currentFilename = nil;
		RFDispatchMainAsync (^{
			handler(0.0);
		});
		return;
	}

	NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
	if (fileAttributes == nil) {
		[fileHandle closeFile];
		self.currentFileID = nil;
		self.currentFilename = nil;
		RFDispatchMainAsync (^{
			handler(0.0);
		});
		return;
	}

	NSNumber* fileSizeNumber = fileAttributes[NSFileSize];
	unsigned long long fileSize = fileSizeNumber.unsignedLongLongValue;

	__block unsigned long long bytesUploaded = 0;
	__block void (^uploadNextChunk)(void) = nil;

	RFDispatchMainAsync (^{
		handler(0.0);
	});

	uploadNextChunk = ^{
		@autoreleasepool {
			NSData* chunkData = [fileHandle readDataOfLength:kUploadChunkSize];
			if (chunkData.length == 0) {
				[fileHandle closeFile];
				return;
			}

			NSString* fileData = [chunkData base64EncodedStringWithOptions:0];
			if (fileData == nil) {
				[fileHandle closeFile];
				self.currentFileID = nil;
				self.currentFilename = nil;
				RFDispatchMainAsync (^{
					handler(0.0);
				});
				return;
			}

			NSUInteger bytesThisChunk = chunkData.length;
			NSDictionary* params = @{
				@"file_id": fileID,
				@"file_data": fileData,
				@"mp-destination": destination_uid
			};
			
			NSLog(@"Upload chunk: %lu, file: %@", (unsigned long)chunkData.length, fileID);
			
			[client postWithParams:params completion:^(UUHttpResponse* response) {
				bytesUploaded += bytesThisChunk;
				CGFloat percent = (CGFloat)bytesUploaded / (CGFloat)fileSize;
				RFDispatchMainAsync (^{
					handler(MIN(percent, 1.0));
				});

				uploadNextChunk();
			}];
		}
	};

	uploadNextChunk();
}

- (void) uploadFinished:(void (^)(BOOL))handler
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media/finished"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	params[@"mp-destination"] = destination_uid;
	params[@"file_id"] = self.currentFileID;
	params[@"file_name"] = self.currentFilename;

	[client postWithParams:params completion:^(UUHttpResponse* response) {
		NSHTTPURLResponse* httpResponse = response.httpResponse;
		BOOL success = NO;
		if (httpResponse != nil) {
			success = (httpResponse.statusCode >= 200) && (httpResponse.statusCode < 300);
		}
		else if (response.httpError == nil) {
			success = YES;
		}

		self.currentFileID = nil;
		self.currentFilename = nil;

		RFDispatchMainAsync (^{
			handler(success);
		});
	}];
}

@end
