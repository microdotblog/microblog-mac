#import <Cocoa/Cocoa.h>

@interface MBMarkdownTextView : NSTextView

@property (assign, nonatomic) NSRange restoredSelection;

- (void) setupMarkdownWithFontSize:(CGFloat)fontSize;

@end
