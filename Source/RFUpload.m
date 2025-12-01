//
//  RFUpload.m
//  Snippets
//
//  Created by Manton Reece on 7/14/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFUpload.h"
#import "RFMacros.h"
#import "UUHttpSession.h"

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
	return ([e isEqualToString:@"mov"] || [e isEqualToString:@"m4v"] || [e isEqualToString:@"mp4"] || [e isEqualToString:@"m3u8"]);
}

- (BOOL) isAudio
{
	NSString* e = [[[self filename] pathExtension] lowercaseString];
	return ([e isEqualToString:@"mp3"] || [e isEqualToString:@"m4a"]);
}

- (NSString *) htmlTag
{
	NSString* s;
	NSString* size_attributes = @"";
	if ((self.width > 0) && (self.height > 0)) {
		size_attributes = [NSString stringWithFormat:@" width=\"%ld\" height=\"%ld\"", (long)self.width, (long)self.height];
	}

	if ([self isVideo]) {
		if (self.poster_url.length > 0) {
			s = [NSString stringWithFormat:@"<video src=\"%@\" poster=\"%@\"%@ controls=\"controls\" playsinline=\"playsinline\" preload=\"metadata\"></video>", self.url, self.poster_url, size_attributes];
		}
		else {
			s = [NSString stringWithFormat:@"<video src=\"%@\"%@ controls=\"controls\" playsinline=\"playsinline\" preload=\"metadata\"></video>", self.url, size_attributes];
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

- (void) ensureDimensionsWithCompletion:(void (^)(void))handler
{
	if (![self isVideo]) {
		RFDispatchMainAsync(^{
			if (handler) {
				handler();
			}
		});
		return;
	}

	if ((self.width > 0) && (self.height > 0)) {
		RFDispatchMainAsync(^{
			if (handler) {
				handler();
			}
		});
		return;
	}

	if (self.poster_url.length == 0) {
		RFDispatchMainAsync(^{
			if (handler) {
				handler();
			}
		});
		return;
	}

	[UUHttpSession get:self.poster_url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		NSImage* img = nil;
		if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
			img = response.parsedResponse;
		}
		else if (response.rawResponse) {
			img = [[NSImage alloc] initWithData:response.rawResponse];
		}

		if (img) {
			NSSize img_size = img.size;
			for (NSImageRep* rep in img.representations) {
				if ((rep.pixelsWide > img_size.width) && (rep.pixelsHigh > img_size.height)) {
					img_size.width = rep.pixelsWide;
					img_size.height = rep.pixelsHigh;
					break;
				}
			}

			self.width = img_size.width;
			self.height = img_size.height;
		}

		RFDispatchMainAsync(^{
			if (handler) {
				handler();
			}
		});
	}];
}

@end
