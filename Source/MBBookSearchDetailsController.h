#import <Cocoa/Cocoa.h>

@class MBBook;

@interface MBBookSearchDetailsController : NSViewController

@property (strong, nonatomic) MBBook* book;

- (void) updateCover;

@end
