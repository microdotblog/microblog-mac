//
//  NSError+Extras.m
//  Micro.blog
//

#import "NSError+Extras.h"

#import "UUHttpSession.h"

@implementation NSError (Extras)

- (NSString *) mb_networkMessageWithResponse:(NSHTTPURLResponse *)response
{
	NSInteger status_code = response.statusCode;
	if (status_code == 0) {
		NSNumber* status_number = [self.userInfo objectForKey:kUUHttpSessionHttpErrorCodeKey];
		status_code = status_number.integerValue;
	}

	if (status_code > 0) {
		NSString* status_text = [NSHTTPURLResponse localizedStringForStatusCode:status_code];
		if (status_text.length > 0) {
			return [NSString stringWithFormat:@"The server returned HTTP %ld (%@).", (long)status_code, status_text];
		}
		else {
			return [NSString stringWithFormat:@"The server returned HTTP %ld.", (long)status_code];
		}
	}

	NSError* underlying_error = [self.userInfo objectForKey:NSUnderlyingErrorKey];
	if (![underlying_error isKindOfClass:[NSError class]]) {
		underlying_error = self;
	}

	if ([underlying_error.domain isEqualToString:NSURLErrorDomain]) {
		switch (underlying_error.code) {
			case NSURLErrorNotConnectedToInternet:
				return @"The internet connection appears to be offline.";

			case NSURLErrorTimedOut:
				return @"The request timed out. Please try again.";

			case NSURLErrorNetworkConnectionLost:
				return @"The network connection was lost. Please try again.";

			case NSURLErrorCannotFindHost:
			case NSURLErrorDNSLookupFailed:
				return @"The server could not be found. Check your internet connection and try again.";

			case NSURLErrorCannotConnectToHost:
				return @"Could not connect to the server. Please try again.";

			case NSURLErrorCancelled:
				return @"The request was cancelled.";
		}
	}

	if (![underlying_error.domain isEqualToString:kUUHttpSessionErrorDomain] && underlying_error.localizedDescription.length > 0) {
		return underlying_error.localizedDescription;
	}

	return @"The request could not be completed. Please try again.";
}

@end
