//
//  MBGlassController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/23/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBGlassController.h"

@implementation MBGlassController

- (instancetype) initWithFile:(NSString *)path
{
	self = [super initWithFile:path];
	if (self) {
		self.path = path;
		self.folder = path;
		
		[self setupPhotos];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTitle];
}

- (void) setupTitle
{
	[self.window setTitle:@"Import from Glass"];
}

- (void) setupPhotos
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* files = [fm contentsOfDirectoryAtPath:self.path error:NULL];
	NSMutableArray* photos = [NSMutableArray array];

	for (NSString* filename in files) {
		// posted date is the file modification date
		NSString* path = [self.path stringByAppendingPathComponent:filename];
		NSDictionary* attrs = [fm attributesOfItemAtPath:path error:NULL];
		NSDate* modified_date = [attrs objectForKey:NSFileModificationDate];

		// put in structure that Instagram base importer understands
		NSDictionary* info = @{
			@"media": @[
				@{
					@"title": @"",
					@"uri": filename,
					@"creation_timestamp": @([modified_date timeIntervalSince1970])
				}
			]
		};
		
		[photos addObject:info];
	}
	
	self.photos = photos;
}

@end
