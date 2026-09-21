#import <Cocoa/Cocoa.h>
#import "MBBookmarkLink.h"
#import "MBBookmarkLinkCell.h"

// Link with MBBookmarkLink.m, MBBookmarkLinkCell.m, and Cocoa.
int main(void)
{
	@autoreleasepool {
		NSDictionary* cases = @{
			@"https://dithering.fm/": @"dithering.fm",
			@"http://example.com/": @"example.com",
			@"https://example.com": @"example.com",
			@"https://example.com:8443/": @"example.com:8443",
			@"https://example.com/posts/": @"example.com/posts/",
			@"https://example.com//": @"example.com//",
			@"https://example.com/%2F": @"example.com/%2F",
			@"https://example.com/?q=test/": @"example.com/?q=test/",
			@"https://example.com/#section/": @"example.com/#section/",
			@"https://example.com/?": @"example.com/?"
		};
		MBBookmarkLinkCell* cell = [[MBBookmarkLinkCell alloc] initWithFrame:NSMakeRect(0, 0, 500, 144)];
		for (NSString* url in cases) {
			MBBookmarkLink* link = [[MBBookmarkLink alloc] initWithDictionary:@{ @"id": @1, @"title": @"Example", @"url": url }];
			[cell configureWithLink:link];
			NSTextField* label = [cell valueForKey:@"urlLabel"];
			NSCAssert([label.stringValue isEqualToString:cases[url]], @"Unexpected display URL for %@: %@", url, label.stringValue);
			NSCAssert([link.url.absoluteString isEqualToString:url], @"Must preserve the actual link");
			NSCAssert([cell.toolTip isEqualToString:url], @"Must preserve the full tooltip URL");
		}
		NSLog(@"Passed 10 bookmark URL display checks.");
	}
	return 0;
}
