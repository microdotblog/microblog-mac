#import <Cocoa/Cocoa.h>

@interface MBLinksController : NSViewController

@property (assign, nonatomic, readonly) BOOL loading;
@property (copy, nonatomic) void (^loadingDidChange)(void);

- (void) reloadLinks;
- (void) focusContent;

@end
