#import <Cocoa/Cocoa.h>

@class MBBookmarkLink;

@interface MBBookmarkLinkCell : NSTableCellView

@property (strong, nonatomic) NSImageView* thumbnailView;
@property (strong, nonatomic) MBBookmarkLink* link;

- (void) configureWithLink:(MBBookmarkLink *)link;

@end
