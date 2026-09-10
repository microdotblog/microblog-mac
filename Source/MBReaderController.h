#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBReaderController : NSWindowController

- (id) initWithBookmarkID:(NSString *)bookmarkID;
+ (nullable NSString *) bookmarkIDForURL:(NSURL *)url;
+ (void) showReaderWithBookmarkID:(NSString *)bookmarkID;

@end

NS_ASSUME_NONNULL_END
