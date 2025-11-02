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
	}
	else if (movie.seasonsCount > 0) {
		self.subtitleField.stringValue = [movie displayYearSeasons];
	}
	else if (movie.year.length > 0) {
		self.subtitleField.stringValue = [movie displayYearDirector];
	}
	else {
		self.subtitleField.stringValue = @"";
	}
	
	self.posterImageView.image = movie.posterImage;
}

@end
