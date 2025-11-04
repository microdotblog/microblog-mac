//
//  MBMovieCell.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMovieCell.h"

#import "MBMovie.h"
#import "RFConstants.h"

@implementation MBMovieCell

- (void) setupWithMovie:(MBMovie *)movie
{
	self.movie = movie;
	self.titleField.stringValue = movie.title;
	self.posterImageView.image = movie.posterImage;

	if (movie.username.length > 0) {
		self.subtitleField.stringValue = [movie displayUsername];
		self.leftConstraint.constant = 12;
		self.disclosureInsetConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	else if (movie.seasonsCount > 0) {
		self.subtitleField.stringValue = [movie displayYearSeasons];
		self.leftConstraint.constant = 40;
		self.disclosureInsetConstraint.constant = 12;
		self.disclosureTriangle.hidden = NO;
	}
	else if (movie.episodesCount > 0) {
		self.subtitleField.stringValue = [movie displayEpisodes];
		self.leftConstraint.constant = 60;
		self.disclosureInsetConstraint.constant = 32;
		self.disclosureTriangle.hidden = NO;
	}
	else if (movie.year.length > 0) {
		self.subtitleField.stringValue = [movie displayYearDirector];
		self.leftConstraint.constant = self.needsInset ? 40 : 12;
		self.disclosureInsetConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	else if (movie.isSearchedEpisode) {
		self.subtitleField.stringValue = movie.airDate;
		self.leftConstraint.constant = 80;
		self.disclosureInsetConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	else {
		self.subtitleField.stringValue = @"";
		self.leftConstraint.constant = self.needsInset ? 40 : 12;
		self.disclosureInsetConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
}

- (void) setDisclosureOpen:(BOOL)isOpen
{
	self.disclosureTriangle.state = isOpen ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	self.postButton.hidden = !selected || (self.movie.username.length > 0);
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
	NSLog(@"new post");
}

@end
