#import "MBBookmarkLinkCell.h"
#import "MBBookmarkLink.h"

@interface MBBookmarkLinkCell()
@property (strong, nonatomic) NSTextField* titleLabel;
@property (strong, nonatomic) NSTextField* urlLabel;
@end

@implementation MBBookmarkLinkCell

- (id) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		self.thumbnailView = [[NSImageView alloc] initWithFrame:NSZeroRect];
		self.thumbnailView.imageScaling = NSImageScaleProportionallyUpOrDown;
		self.thumbnailView.wantsLayer = YES;
		self.thumbnailView.layer.cornerRadius = 5;
		self.thumbnailView.layer.masksToBounds = YES;
		self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.thumbnailView];
		self.titleLabel = [NSTextField wrappingLabelWithString:@""];
		self.titleLabel.font = [NSFont boldSystemFontOfSize:15];
		self.titleLabel.maximumNumberOfLines = 3;
		self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
		self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.titleLabel];
		self.urlLabel = [NSTextField labelWithString:@""];
		self.urlLabel.font = [NSFont systemFontOfSize:13];
		self.urlLabel.textColor = [NSColor textColor];
		self.urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		self.urlLabel.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.urlLabel];
		NSLayoutGuide* text_group = [[NSLayoutGuide alloc] init];
		[self addLayoutGuide:text_group];
		[NSLayoutConstraint activateConstraints:@[
			[self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
			[self.thumbnailView.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
			[self.thumbnailView.widthAnchor constraintEqualToConstant:120],
			[self.thumbnailView.heightAnchor constraintEqualToConstant:120],
			[text_group.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:16],
			[text_group.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
			[text_group.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
			[self.titleLabel.leadingAnchor constraintEqualToAnchor:text_group.leadingAnchor],
			[self.titleLabel.trailingAnchor constraintEqualToAnchor:text_group.trailingAnchor],
			[self.titleLabel.topAnchor constraintEqualToAnchor:text_group.topAnchor],
			[self.urlLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
			[self.urlLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
			[self.urlLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
			[self.urlLabel.bottomAnchor constraintEqualToAnchor:text_group.bottomAnchor]
		]];
	}
	return self;
}

- (void) configureWithLink:(MBBookmarkLink *)link
{
	self.link = link;
	self.titleLabel.stringValue = link.title.length ? link.title : link.url.host;
	NSString* display_url = link.url.absoluteString;
	NSRange scheme_range = [display_url rangeOfString:@"://"];
	if (scheme_range.location != NSNotFound) {
		display_url = [display_url substringFromIndex:NSMaxRange(scheme_range)];
	}
	self.urlLabel.stringValue = display_url;
	self.toolTip = link.url.absoluteString;
	self.thumbnailView.image = nil;
}

- (void) layout
{
	CGFloat text_width = MAX(1, self.bounds.size.width - 168);
	if (self.titleLabel.preferredMaxLayoutWidth != text_width) {
		self.titleLabel.preferredMaxLayoutWidth = text_width;
	}
	[super layout];
}

- (void) setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
	[super setBackgroundStyle:backgroundStyle];
	BOOL selected = backgroundStyle == NSBackgroundStyleEmphasized;
	self.titleLabel.textColor = selected ? [NSColor alternateSelectedControlTextColor] : [NSColor labelColor];
	self.urlLabel.textColor = selected ? [NSColor alternateSelectedControlTextColor] : [NSColor textColor];
}

@end
