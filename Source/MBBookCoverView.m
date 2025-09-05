//
//  MBBookCoverView.m
//  Micro.blog
//
//  Created by Manton Reece on 9/5/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBBookCoverView.h"

#import "MBBook.h"
#import "NSString+Extras.h"
#import "UUHttpSession.h"
#import "RFMacros.h"

@implementation MBBookCoverView

- (void) setupWithISBN:(NSString *)isbn
{
	NSString* url = [NSString stringWithFormat:@"https://micro.blog/books/%@/cover.jpg", isbn];

	[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
			NSImage* img = response.parsedResponse;
			RFDispatchMain(^{
				self.image = img;
			});
		}
	}];
}

@end
