//
//  MBMovieCell.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMovieCell.h"

#import "MBMovie.h"

@implementation MBMovieCell

- (void) setupWithMovie:(MBMovie *)movie
{
	self.titleField.stringValue = movie.title;
	if (movie.username.length > 0) {
		self.subtitleField.stringValue = [movie displayUsername];
		self.leftConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	else if (movie.seasonsCount > 0) {
		self.subtitleField.stringValue = [movie displayYearSeasons];
		self.leftConstraint.constant = 40;
		self.disclosureTriangle.hidden = NO;
	}
	else if (movie.year.length > 0) {
		self.subtitleField.stringValue = [movie displayYearDirector];
		self.leftConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	else {
		self.subtitleField.stringValue = @"";
		self.leftConstraint.constant = 12;
		self.disclosureTriangle.hidden = YES;
	}
	
	self.posterImageView.image = movie.posterImage;
}

- (IBAction) toggleDisclosure:(id)sender
{
	NSLog(@"click");
}

@end
