#import <Foundation/Foundation.h>
#import "RFAccount.h"

// Link with Source/RFAccount.m and Cocoa. No network or account settings are accessed.
int main(void)
{
	@autoreleasepool {
		NSArray* invalid_responses = @[
			@"<html>Bad Gateway</html>", @"", @[], @42, [NSNull null], @{},
			@{ @"username": [NSNull null] }, @{ @"username": @123 },
			@{ @"username": @"" }, @{ @"username": @" \n" },
			@{ @"error": @"App token was not valid." },
			@{ @"username": @"test", @"error": @"App token was not valid." },
			@{ @"username": @"test", @"error": @[] }
		];
		NSCAssert([RFAccount accountInfoFromVerificationResponse:nil] == nil, @"Reject nil responses");
		for (id response in invalid_responses) {
			NSCAssert([RFAccount accountInfoFromVerificationResponse:response] == nil, @"Reject invalid response: %@", response);
		}
		NSDictionary* valid_response = @{
			@"username": @"test", @"full_name": @"Test User", @"email": @"test@example.com",
			@"gravatar_url": @"https://example.com/avatar.jpg", @"default_site": @"test.micro.blog",
			@"has_site": @YES, @"is_premium": @NO, @"is_using_ai": @YES
		};
		NSCAssert([[RFAccount accountInfoFromVerificationResponse:valid_response] isEqual:valid_response], @"Preserve valid account values, including false flags");
		NSDictionary* minimal_response = @{ @"username": @"test" };
		NSCAssert([[RFAccount accountInfoFromVerificationResponse:minimal_response] isEqual:minimal_response], @"Allow missing optional fields");
		NSMutableDictionary* response = [valid_response mutableCopy];
		for (NSString* key in valid_response) {
			if ([key isEqualToString:@"username"]) {
				continue;
			}
			response[key] = @[];
			NSCAssert([RFAccount accountInfoFromVerificationResponse:response] == nil, @"Reject malformed %@", key);
			response[key] = [NSNull null];
			NSDictionary* info = [RFAccount accountInfoFromVerificationResponse:response];
			NSCAssert(info && !info[key], @"Omit null %@ without clearing saved settings", key);
			response[key] = valid_response[key];
		}
		response[@"is_premium"] = @"false";
		NSCAssert([RFAccount accountInfoFromVerificationResponse:response] == nil, @"Flags must be JSON booleans/numbers");
		response = [minimal_response mutableCopy];
		response[@"error"] = [NSNull null];
		NSCAssert([[RFAccount accountInfoFromVerificationResponse:response] isEqual:minimal_response], @"A null error is not a rejection");
		NSLog(@"Passed account verification response checks.");
	}
	return 0;
}
