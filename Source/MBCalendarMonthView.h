#import <Cocoa/Cocoa.h>

// One reusable card per month. Images are supplied by the controller's cache.
@interface MBCalendarMonthView : NSTableCellView

@property (strong, nonatomic) NSDictionary* month;
@property (copy, nonatomic) NSImage* (^imageForURL)(NSString* url);
@property (assign, nonatomic) NSInteger selectedBookIndex;

- (NSInteger) bookIndexAtPoint:(NSPoint)point;

@end
