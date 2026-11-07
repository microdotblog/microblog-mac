#import "MBMarkdownTextView.h"
#import "RFHighlightingTextStorage.h"

@interface MBMarkdownTextView ()
@property (strong, nonatomic) RFHighlightingTextStorage* highlightingTextStorage;
@end

@implementation MBMarkdownTextView

- (void) setupMarkdownWithFontSize:(CGFloat)fontSize
{
	NSString* text = [self.string copy];
	NSFont* font = [NSFont systemFontOfSize:fontSize];
	self.richText = YES;
	self.importsGraphics = NO;
	self.automaticQuoteSubstitutionEnabled = NO;
	self.automaticDashSubstitutionEnabled = NO;
	self.font = font;
	self.highlightingTextStorage = [[RFHighlightingTextStorage alloc] initWithFontSize:fontSize];
	[self.layoutManager replaceTextStorage:self.highlightingTextStorage];
	self.typingAttributes = @{ NSFontAttributeName: font };
	self.string = text;
}

- (BOOL) shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
{
	if (affectedCharRange.location > self.string.length || affectedCharRange.length > self.string.length - affectedCharRange.location) {
		return NO;
	}

	self.restoredSelection = NSMakeRange(affectedCharRange.location + replacementString.length, 0);
	return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
}

- (void) didChangeText
{
	[super didChangeText];
	self.selectedRange = self.restoredSelection;
}

- (NSPasteboardType) preferredPasteboardTypeFromArray:(NSArray *)availableTypes restrictedToTypesFromArray:(NSArray *)allowedTypes
{
	if ([availableTypes containsObject:NSPasteboardTypeString] && (allowedTypes == nil || [allowedTypes containsObject:NSPasteboardTypeString])) {
		return NSPasteboardTypeString;
	}
	return [super preferredPasteboardTypeFromArray:availableTypes restrictedToTypesFromArray:allowedTypes];
}

@end
