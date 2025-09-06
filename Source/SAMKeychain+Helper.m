//
//  SAMKeychain+Helper.m
//  Micro.blog
//
//  Created by Manton Reece on 9/6/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "SAMKeychain+Helper.h"

static const NSTimeInterval kKeychainCooldownSeconds = 30;
static NSDate* sLastKeychainAttempt = nil;

@implementation SAMKeychain (Helper)

+ (NSString *) mb_passwordForService:(NSString *)serviceName account:(NSString *)account
{
	// keep track of whether we tried and failed recently
	BOOL within_cooldown = NO;
	if (sLastKeychainAttempt) {
		NSTimeInterval elapsed = -[sLastKeychainAttempt timeIntervalSinceNow];
		within_cooldown = (elapsed < kKeychainCooldownSeconds);
	}

	// fail quickly if cooldown
	if (within_cooldown) {
		return nil;
	}
	else {
		// get the keychain value
		NSString* pw = [SAMKeychain passwordForService:serviceName account:account];
		if (pw == nil) {
			sLastKeychainAttempt = [NSDate date];
		}
		return pw;
	}
}

@end
