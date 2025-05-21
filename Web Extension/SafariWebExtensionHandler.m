//
//  SafariWebExtensionHandler.m
//  Web Extension
//
//  Created by Manton Reece on 5/18/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "SafariWebExtensionHandler.h"

#import <SafariServices/SafariServices.h>

@implementation SafariWebExtensionHandler

- (void) beginRequestWithExtensionContext:(NSExtensionContext *)context
{
    NSExtensionItem* request = context.inputItems.firstObject;

    NSUUID *profile;
    if (@available(iOS 17.0, macOS 14.0, *)) {
        profile = request.userInfo[SFExtensionProfileKey];
    } else {
        profile = request.userInfo[@"profile"];
    }

    id message = request.userInfo[SFExtensionMessageKey];

    NSLog(@"Received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", message, profile.UUIDString ?: @"none");

	NSString* command = message[@"type"];
	NSMutableDictionary *reply = [NSMutableDictionary dictionary];

	if ([command isEqualToString:@"GET_TOKEN"]) {
		NSUserDefaults* shared_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"blog.micro.mac.shared"];
		NSString* token = [shared_defaults stringForKey:@"micropub_token"];
		if (token) {
			reply[@"token"] = token;
		}
		else {
			reply[@"error"] = @"Token not found";
		}
	}
	else {
		reply[@"echo"] = message;
	}

    NSExtensionItem* response = [[NSExtensionItem alloc] init];
	response.userInfo = @{ SFExtensionMessageKey: @{ @"echo": message } };

    [context completeRequestReturningItems:@[ response ] completionHandler:nil];
}

@end
