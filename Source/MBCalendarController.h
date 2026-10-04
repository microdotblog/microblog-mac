#import <Cocoa/Cocoa.h>

@interface MBCalendarController : NSViewController

@property (assign, nonatomic, readonly) BOOL loading;
@property (copy, nonatomic) void (^loadingDidChange)(void);

- (void) reloadCalendar;
- (void) focusContent;

@end
