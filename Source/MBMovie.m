//
//  MBMovie.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMovie.h"

@implementation MBMovie

- (NSString *) displayUsername
{
	return [NSString stringWithFormat:@"@%@", self.username];
}

- (NSString *) displayYearDirector
{
	return [NSString stringWithFormat:@"%@ • %@", self.year, self.director];
}

- (NSString *) displayYearSeasons
{
	if (self.seasonsCount == 1) {
		return [NSString stringWithFormat:@"%@ • 1 season", self.year];
	}
	else {
		return [NSString stringWithFormat:@"%@ • %ld seasons", self.year, (long)self.seasonsCount];
	}
}

- (BOOL) hasSeasons
{
	return (self.seasonsCount > 0);
}

- (BOOL) hasEpisodes
{
	return (self.episodesCount > 0);
}

@end
