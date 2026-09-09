#import <Foundation/Foundation.h>

@interface MBBookmarkLink : NSObject

@property (copy, nonatomic) NSString* linkID;
@property (copy, nonatomic) NSString* title;
@property (strong, nonatomic) NSURL* url;
@property (strong, nonatomic) NSURL* thumbnailURL;

- (id) initWithDictionary:(NSDictionary *)dictionary;

@end
