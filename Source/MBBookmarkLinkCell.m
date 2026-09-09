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
		self.urlLabel.textColor = [NSColor linkColor];
		self.urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		self.urlLabel.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.urlLabel];
		[NSLayoutConstraint activateConstraints:@[
			[self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
			[self.thumbnailView.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
			[self.thumbnailView.widthAnchor constraintEqualToConstant:120],
			[self.thumbnailView.heightAnchor constraintEqualToConstant:120],
			[self.titleLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:16],
			[self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
			[self.titleLabel.topAnchor constraintEqualToAnchor:self.thumbnailView.topAnchor],
			[self.urlLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
			[self.urlLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
			[self.urlLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8]
		]];
	}
	return self;
}

- (void) configureWithLink:(MBBookmarkLink *)link
{
	self.link = link;
	self.titleLabel.stringValue = link.title.length ? link.title : link.url.host;
	self.urlLabel.stringValue = link.url.absoluteString;
	self.toolTip = link.url.absoluteString;
	self.thumbnailView.image = [NSImage imageWithSystemSymbolName:@"link" accessibilityDescription:@"Web page"];
}

- (void) layout
{
	CGFloat text_width = MAX(1, self.bounds.size.width - 168);
	if (self.titleLabel.preferredMaxLayoutWidth != text_width) {
		self.titleLabel.preferredMaxLayoutWidth = text_width;
	}
	[super layout];
}

@end
