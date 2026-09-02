//
//  MBMovieCell.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMovieCell.h"

#import "MBMovie.h"
#import "RFRoundedImageView.h"
#import "RFConstants.h"
#import "NSString+Extras.h"

static CGFloat const kPosterCornerRadius = 4.0;

@implementation MBMoviePosterImageView

- (NSRect) displayedImageRect
{
	NSSize image_size = self.image.size;
	NSRect bounds = NSInsetRect(self.bounds, 1.0, 1.0);
	if ((image_size.width <= 0) || (image_size.height <= 0) || (bounds.size.width <= 0) || (bounds.size.height <= 0)) {
		return NSZeroRect;
	}

	CGFloat scale = MIN(bounds.size.width / image_size.width, bounds.size.height / image_size.height);
	if (self.imageScaling == NSImageScaleProportionallyDown) {
		scale = MIN(scale, 1.0);
	}

	NSSize displayed_size = NSMakeSize(image_size.width * scale, image_size.height * scale);
	CGFloat y = NSMidY(bounds) - (displayed_size.height / 2.0);
	return NSMakeRect(NSMinX(bounds), y, displayed_size.width, displayed_size.height);
}

- (void) drawRect:(NSRect)dirtyRect
{
	NSRect image_rect = [self displayedImageRect];
	if (NSIsEmptyRect(image_rect)) {
		[super drawRect:dirtyRect];
		return;
	}

	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRoundedRect:image_rect xRadius:kPosterCornerRadius yRadius:kPosterCornerRadius] addClip];
	[NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationHigh;
	[self.image drawInRect:image_rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
	[NSGraphicsContext restoreGraphicsState];
}

@end

@interface MBMovieCell ()

@property (assign, nonatomic) CGFloat statusLeftDefaultConstant;
@property (assign, nonatomic) BOOL hasStatusLeftDefaultConstant;

@end

@implementation MBMovieCell

- (void) setupWithMovie:(MBMovie *)movie
{
	self.movie = movie;
	self.titleField.stringValue = movie.title;
	self.posterImageView.image = movie.posterImage;
	self.profileImageView.image = nil;
	self.profileImageView.hidden = (movie.profileImageURL.length == 0);

	if (!self.hasStatusLeftDefaultConstant) {
		self.statusLeftDefaultConstant = self.statusLeftConstraint.constant;
		self.hasStatusLeftDefaultConstant = YES;
	}
	self.statusLeftConstraint.constant = self.statusLeftDefaultConstant + (self.profileImageView.hidden ? 0 : 22);

	if (movie.profileImageURL.length > 0) {
		[self.profileImageView loadFromURL:movie.profileImageURL];
	}

	if (movie.username.length > 0) {
		self.subtitleField.stringValue = [movie displayUsername];
		self.leftConstraint.constant = 18;
		self.disclosureInsetConstraint.constant = 18;
		self.disclosureTriangle.hidden = YES;
	}
	else if (movie.seasonsCount > 0) {
		self.subtitleField.stringValue = [movie displayYearSeasons];
		self.leftConstraint.constant = 44;
		self.disclosureInsetConstraint.constant = 18;
		self.disclosureTriangle.hidden = NO;
	}
	else if (movie.episodesCount > 0) {
		self.subtitleField.stringValue = [movie displayEpisodes];
		self.leftConstraint.constant = 64;
		self.disclosureInsetConstraint.constant = 36;
		self.disclosureTriangle.hidden = NO;
	}
	else if (movie.year.length > 0) {
		self.subtitleField.stringValue = [movie displayYearDirector];
		self.leftConstraint.constant = self.needsInset ? 44 : 18;
		self.disclosureInsetConstraint.constant = 18;
		self.disclosureTriangle.hidden = YES;
	}
	else if (movie.isSearchedEpisode) {
		self.subtitleField.stringValue = movie.airDate;
		self.leftConstraint.constant = 84;
		self.disclosureInsetConstraint.constant = 18;
		self.disclosureTriangle.hidden = YES;
	}
	else {
		self.subtitleField.stringValue = @"";
		self.leftConstraint.constant = self.needsInset ? 44 : 18;
		self.disclosureInsetConstraint.constant = 18;
		self.disclosureTriangle.hidden = YES;
	}

	[self updateTextColors];
}

- (void) setDisclosureOpen:(BOOL)isOpen
{
	self.disclosureTriangle.state = isOpen ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	self.postButton.hidden = !selected || (self.movie.username.length > 0);
	[self updateTextColors];
}

- (void) setEmphasized:(BOOL)emphasized
{
	[super setEmphasized:emphasized];

	[self updateTextColors];
}

- (void) updateTextColors
{
	if (self.selected && self.emphasized) {
		self.subtitleField.textColor = [NSColor selectedControlTextColor];
	}
	else {
		self.subtitleField.textColor = [NSColor colorNamed:@"color_date_text"];
	}
}

#pragma mark -

- (NSTableView *) findTableView
{
	NSView* view = self.superview;
	while (view != nil && ![view isKindOfClass:[NSTableView class]]) {
		view = view.superview;
	}

	return (NSTableView *)view;
}

- (IBAction) toggleDisclosure:(id)sender
{
	NSTableView* table = [self findTableView];
	NSInteger row = -1;

	if (table != nil) {
		row = [table rowForView:self];
	}
	if (row >= 0) {
		NSDictionary* info = (row >= 0) ? @{ kToggleMovieDisclosureRowKey: @(row) } : nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:kToggleMovieDisclosureNotification object:self userInfo:info];
	}
}

- (IBAction) startPost:(id)sender
{
	NSString* text = self.movie.postText;
	if (text.length == 0) {
		return;
	}

	NSString* encoded = [text rf_urlEncoded];
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"microblog://post?text=%@", encoded]];

	[[NSNotificationCenter defaultCenter] postNotificationName:kOpenMicroblogURLNotification object:self userInfo:@{ kOpenMicroblogURLKey: url }];
}

@end
