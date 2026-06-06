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
	NSString* s = [NSString stringWithFormat:@"@%@", self.username];
	if (self.url.length > 0) {
		NSURL* url = [NSURL URLWithString:self.url];
		if (url.host.length > 0) {
			s = [s stringByAppendingFormat:@" • %@", url.host];
		}
	}

	return s;
}

- (NSString *) displayYearDirector
{
	return [NSString stringWithFormat:@"%@ • Directed by %@", self.year, self.director];
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

- (NSString *) displayEpisodes
{
	if (self.episodesCount == 1) {
		return @"1 episode";
	}
	else {
		return [NSString stringWithFormat:@"%ld episodes", (long)self.episodesCount];
	}
}

#pragma mark -

- (BOOL) hasSeasons
{
	return (self.seasonsCount > 0);
}

- (BOOL) hasEpisodes
{
	return (self.episodesCount > 0);
}

@end
