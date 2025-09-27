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
#import "NSString+Extras.h"

@implementation MBUploadProgress

- (void) uploadFileInBackground:(NSString *)path completion:(void (^)(CGFloat))handler
{
	NSString* filename = [path lastPathComponent];
	NSString* content_type = [path mb_contentType];
	NSData* d = nil;
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/micropub/media/part"];
	NSString* destination_uid = [RFSettings stringForKey:kCurrentDestinationUID];
	if (destination_uid == nil) {
		destination_uid = @"";
	}
	NSDictionary* args = @{
		@"mp-destination": destination_uid
	};
	[client uploadFileData:d named:@"file" filename:filename contentType:content_type httpMethod:@"POST" queryArguments:args completion:^(UUHttpResponse* response) {
	}];
}

@end
