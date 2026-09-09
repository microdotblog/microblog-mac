#import "MBBookmarkLink.h"

@implementation MBBookmarkLink

- (id) initWithDictionary:(NSDictionary *)dictionary
{
	self = [super init];
	if (self) {
		id link_id = dictionary[@"id"];
		self.linkID = [link_id isKindOfClass:[NSNumber class]] ? [link_id stringValue] : ([link_id isKindOfClass:[NSString class]] ? link_id : @"");
		self.title = [dictionary[@"title"] isKindOfClass:[NSString class]] ? dictionary[@"title"] : @"";
		NSString* url_string = [dictionary[@"url"] isKindOfClass:[NSString class]] ? dictionary[@"url"] : @"";
		self.url = [self webURL:url_string];
		NSDictionary* metadata = [dictionary[@"_microblog"] isKindOfClass:[NSDictionary class]] ? dictionary[@"_microblog"] : @{};
		if ([metadata[@"thumbnail_url"] isKindOfClass:[NSString class]]) {
			self.thumbnailURL = [self webURL:metadata[@"thumbnail_url"]];
		}
	}
	return self;
}

- (NSURL *) webURL:(NSString *)string
{
	NSURL* url = [NSURL URLWithString:string];
	if ((url.host.length > 0) && ([@[@"http", @"https"] containsObject:url.scheme.lowercaseString])) {
		return url;
	}
	return nil;
}

@end
