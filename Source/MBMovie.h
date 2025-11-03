//
//  MBMovie.h
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBMovie : NSObject

@property (strong) NSString* tmdbID;
@property (strong) NSString* url;
@property (strong) NSString* title;
@property (strong) NSString* username;
@property (strong) NSString* posterURL;
@property (strong) NSImage* posterImage;
@property (strong) NSString* year;
@property (strong) NSString* director;
@property (assign) NSInteger seasonsCount;
@property (assign) NSInteger episodesCount;

- (NSString *) displayUsername;
- (NSString *) displayYearDirector;
- (NSString *) displayYearSeasons;
- (BOOL) hasSeasons;
- (BOOL) hasEpisodes;

@end

NS_ASSUME_NONNULL_END
