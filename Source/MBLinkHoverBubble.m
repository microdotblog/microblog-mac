#import "MBLinkHoverBubble.h"

@implementation MBLinkHoverBubble

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.hidden = YES;
		self.textField = [NSTextField labelWithString:@""];
		self.textField.translatesAutoresizingMaskIntoConstraints = NO;
		self.textField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
		self.textField.textColor = [NSColor secondaryLabelColor];
		self.textField.lineBreakMode = NSLineBreakByTruncatingMiddle;
		self.textField.maximumNumberOfLines = 1;
		self.textField.usesSingleLineMode = YES;
		[self.textField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
		[self addSubview:self.textField];
		[NSLayoutConstraint activateConstraints:@[
			[self.textField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
			[self.textField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
			[self.textField.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
			[self.textField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]
		]];
	}
	return self;
}

- (NSView *) hitTest:(NSPoint)point
{
	// Let the page underneath receive clicks, even when the pill covers a link.
	return nil;
}

- (void) viewDidChangeEffectiveAppearance
{
	[super viewDidChangeEffectiveAppearance];
	self.needsDisplay = YES;
}

- (void) drawRect:(NSRect)dirtyRect
{
	NSString* appearance = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
	CGFloat white = [appearance isEqualToString:NSAppearanceNameDarkAqua] ? 0.100 : 0.952;
	[[NSColor colorWithWhite:white alpha:1] setFill];
	[[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:14 yRadius:14] fill];
}

@end
