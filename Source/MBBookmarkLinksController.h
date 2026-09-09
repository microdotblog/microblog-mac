#import <Cocoa/Cocoa.h>

@interface MBBookmarkLinksController : NSViewController

@property (assign, nonatomic, readonly) BOOL loading;
@property (copy, nonatomic) void (^loadingDidChange)(void);

- (void) reloadLinks;
- (void) focusContent;

@end
