//
//  RFUpload.m
//  Snippets
//
//  Created by Manton Reece on 7/14/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFUpload.h"

@implementation RFUpload

- (instancetype) initWithURL:(NSString *)url
{
	self = [super init];
	if (self) {
		self.url = url;
	}
	
	return self;
}

- (NSString *) filename
{
	return [self.url lastPathComponent];
}

- (BOOL) isPhoto
{
	NSString* e = [[[self filename] pathExtension] lowercaseString];
	return ([e isEqualToString:@"jpg"] || [e isEqualToString:@"jpeg"] || [e isEqualToString:@"png"] || [e isEqualToString:@"gif"] || [e isEqualToString:@"webp"]);
}

- (BOOL) isVideo
{
	NSString* e = [[[self filename] pathExtension] lowercaseString];
	return ([e isEqualToString:@"mov"] || [e isEqualToString:@"m4v"] || [e isEqualToString:@"mp4"]);
}

- (BOOL) isAudio
{
	NSString* e = [[[self filename] pathExtension] lowercaseString];
	return ([e isEqualToString:@"mp3"] || [e isEqualToString:@"m4a"]);
}

- (NSString *) htmlTag
{
	NSString* s;

	if ([self isVideo]) {
		if (self.poster_url.length > 0) {
			s = [NSString stringWithFormat:@"<video src=\"%@\" poster=\"%@\" controls=\"controls\" playsinline=\"playsinline\" preload=\"metadata\"></video>", self.url, self.poster_url];
		}
		else {
			s = [NSString stringWithFormat:@"<video src=\"%@\" controls=\"controls\" playsinline=\"playsinline\" preload=\"metadata\"></video>", self.url];
		}
	}
	else if ([self isAudio]) {
		s = [NSString stringWithFormat:@"<audio src=\"%@\" controls=\"controls\" preload=\"metadata\"></audio>", self.url];
	}
	else if ([self isPhoto]) {
		if (self.alt.length > 0) {
			NSString* alt_cleaned = [self.alt stringByReplacingOccurrencesOfString:@"\"" withString:@""];
			s = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"%@\">", self.url, alt_cleaned];
		}
		else {
			s = [NSString stringWithFormat:@"<img src=\"%@\">", self.url];
		}
	}
	else {
		s = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", self.url, [self filename]];
	}

	return s;
}

@end
