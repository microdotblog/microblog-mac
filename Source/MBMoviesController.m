//
//  MBMoviesController.m
//  Micro.blog
//
//  Created by Manton Reece on 10/31/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBMoviesController.h"

#import "MBMovieCell.h"
#import "MBMovie.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"

@implementation MBMoviesController

- (id) init
{
	self = [super initWithNibName:@"Movies" bundle:nil];
	if (self) {
		self.movies = @[];
		self.openSeasons = [NSMutableDictionary dictionary];
		self.openEpisodes = [NSMutableDictionary dictionary];
	}

	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieCellDidToggleDisclosure:) name:kToggleMovieDisclosureNotification object:nil];
	
	[self fetchDiscover];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"MovieCell" bundle:nil] forIdentifier:@"MovieCell"];
	[self.tableView setTarget:self];
	[self.tableView setDoubleAction:@selector(openRow:)];
	self.tableView.alphaValue = 0.0;
}

- (void) focusSearch
{
	[self.searchField becomeFirstResponder];
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length > 2) {
		[self.progressSpinner startAnimation:nil];
		[self fetchMoviesWithSearch:s];
	}
	else {
		self.movies = @[];
		[self.openSeasons removeAllObjects];
		[self.openEpisodes removeAllObjects];
		[self.tableView reloadData];
	}
}

- (IBAction) openRow:(id)sender
{
	NSInteger row = [self.tableView clickedRow];
	if (row < 0) {
		row = [self.tableView selectedRow];
	}
		
	if (row >= 0) {
		if (row >= (NSInteger)self.movies.count) {
			return;
		}
		MBMovie* m = [self.movies objectAtIndex:row];
		if ([m hasSeasons]) {
			[self expandSeasons:m forRow:row];
		}
		else if ([m hasEpisodes]) {
			[self expandEpisodes:m forRow:row];
		}
		else if (m.url.length > 0) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:m.url]];
		}
	}
}

- (NSString *) episodeDictionaryKeyForMovie:(MBMovie *)movie
{
	if (movie == nil) {
		return nil;
	}

	NSString* baseIdentifier = movie.tmdbID;
	if (baseIdentifier.length == 0) {
		baseIdentifier = [NSString stringWithFormat:@"%p", movie];
	}

	return [NSString stringWithFormat:@"%@-%ld", baseIdentifier, (long)movie.seasonNumber];
}

- (void) movieCellDidToggleDisclosure:(NSNotification *)notification
{
	NSNumber* num = [notification.userInfo objectForKey:kToggleMovieDisclosureRowKey];
	if (num == nil) {
		return;
	}

	NSInteger row = [num integerValue];
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	MBMovie* movie = [self.movies objectAtIndex:row];
	if ([movie hasSeasons]) {
		[self expandSeasons:movie forRow:row];
	}
	else if ([movie hasEpisodes]) {
		[self expandEpisodes:movie forRow:row];
	}
	else {
		[self toggleDisclosureOpen:NO atRow:row];
	}
}

- (void) moveLeft
{
	NSInteger row = [self.tableView selectedRow];
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	MBMovie* m = [self.movies objectAtIndex:row];
	if ([m hasSeasons] || [m hasEpisodes]) {
		[self toggleDisclosureOpen:NO atRow:row];
		[self collapseRow:row];
	}
}

- (void) moveRight
{
	NSInteger row = [self.tableView selectedRow];
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	MBMovie* m = [self.movies objectAtIndex:row];
	if ([m hasSeasons]) {
		[self expandSeasons:m forRow:row];
	}
	else if ([m hasEpisodes]) {
		[self expandEpisodes:m forRow:row];
	}
}

- (void) expandSeasons:(MBMovie *)movie forRow:(NSInteger)row
{
	if (movie.tmdbID.length == 0) {
		return;
	}
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	NSArray* alreadyOpen = [self.openSeasons objectForKey:movie.tmdbID];
	if (alreadyOpen != nil) {
		if (alreadyOpen.count > 0) {
			NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
			if (movieIndex != NSNotFound) {
				[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
				[self collapseRow:(NSInteger)movieIndex];
			}
		}
		return;
	}

	[self toggleDisclosureOpen:YES atRow:row];
	[self.openSeasons setObject:@[] forKey:movie.tmdbID];

	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/movies/discover/%@", movie.tmdbID];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_seasons = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.posterURL = [item objectForKey:@"image"];
				m.title = [item objectForKey:@"title"];
				NSDictionary* metadata = [item objectForKey:@"_microblog"];
				if ([metadata isKindOfClass:[NSDictionary class]]) {
					m.tmdbID = [metadata objectForKey:@"tmdb_id"];
					m.episodesCount = [[metadata objectForKey:@"episode_count"] integerValue];
					m.year = [metadata objectForKey:@"year"] ?: @"";
					m.seasonNumber = [[metadata objectForKey:@"season_number"] integerValue];
					m.postText = [metadata objectForKey:@"post_text"];
				}
				
				[new_seasons addObject:m];
			}
			
			RFDispatchMainAsync (^{
				NSArray* storedValue = [self.openSeasons objectForKey:movie.tmdbID];
				if (storedValue == nil) {
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				if (new_seasons.count == 0) {
					NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
					if (movieIndex != NSNotFound) {
						[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
					}
					[self.openSeasons removeObjectForKey:movie.tmdbID];
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
				if (movieIndex == NSNotFound) {
					[self.openSeasons removeObjectForKey:movie.tmdbID];
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				[self.openSeasons setObject:new_seasons forKey:movie.tmdbID];
				NSMutableArray* updatedMovies = [self.movies mutableCopy];
				if (updatedMovies == nil) {
					updatedMovies = [NSMutableArray array];
				}
				NSMutableIndexSet* insertIndexes = [NSMutableIndexSet indexSet];
				NSUInteger insertIndex = movieIndex + 1;
				for (NSUInteger i = 0; i < new_seasons.count; i++) {
					[updatedMovies insertObject:[new_seasons objectAtIndex:i] atIndex:insertIndex + i];
					[insertIndexes addIndex:insertIndex + i];
				}
				self.movies = updatedMovies;
				[self.tableView insertRowsAtIndexes:insertIndexes withAnimation:NSTableViewAnimationSlideDown];

				[self.progressSpinner stopAnimation:nil];
			});
		}
		else {
			RFDispatchMainAsync (^{
				NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
				if (movieIndex != NSNotFound) {
					[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
				}
				[self.openSeasons removeObjectForKey:movie.tmdbID];
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) expandEpisodes:(MBMovie *)movie forRow:(NSInteger)row
{
	if (movie.tmdbID.length == 0) {
		return;
	}
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	NSString* episodeKey = [self episodeDictionaryKeyForMovie:movie];
	if (episodeKey.length == 0) {
		return;
	}

	NSArray* alreadyOpen = [self.openEpisodes objectForKey:episodeKey];
	if (alreadyOpen != nil) {
		if (alreadyOpen.count > 0) {
			NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
			if (movieIndex != NSNotFound) {
				[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
				[self collapseRow:(NSInteger)movieIndex];
			}
		}
		return;
	}

	[self toggleDisclosureOpen:YES atRow:row];
	[self.openEpisodes setObject:@[] forKey:episodeKey];

	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/movies/discover/%@/seasons/%d", movie.tmdbID, movie.seasonNumber];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_episodes = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.isSearchedEpisode = YES;
				m.posterURL = [item objectForKey:@"image"];
				m.title = [item objectForKey:@"title"];
				NSDictionary* metadata = [item objectForKey:@"_microblog"];
				if ([metadata isKindOfClass:[NSDictionary class]]) {
					m.tmdbID = [metadata objectForKey:@"tmdb_id"];
					m.url = [metadata objectForKey:@"url"];
					m.airDate = [metadata objectForKey:@"air_date"];
					m.postText = [metadata objectForKey:@"post_text"];
				}
				
				[new_episodes addObject:m];
			}
			
			RFDispatchMainAsync (^{
				NSArray* storedValue = [self.openEpisodes objectForKey:episodeKey];
				if (storedValue == nil) {
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				if (new_episodes.count == 0) {
					NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
					if (movieIndex != NSNotFound) {
						[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
					}
					[self.openEpisodes removeObjectForKey:episodeKey];
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				NSUInteger seasonIndex = [self.movies indexOfObjectIdenticalTo:movie];
				if (seasonIndex == NSNotFound) {
					[self.openEpisodes removeObjectForKey:episodeKey];
					[self.progressSpinner stopAnimation:nil];
					return;
				}

				[self.openEpisodes setObject:new_episodes forKey:episodeKey];
				NSMutableArray* updatedMovies = [self.movies mutableCopy];
				if (updatedMovies == nil) {
					updatedMovies = [NSMutableArray array];
				}
				NSMutableIndexSet* insertIndexes = [NSMutableIndexSet indexSet];
				NSUInteger insertIndex = seasonIndex + 1;
				for (NSUInteger i = 0; i < new_episodes.count; i++) {
					[updatedMovies insertObject:[new_episodes objectAtIndex:i] atIndex:insertIndex + i];
					[insertIndexes addIndex:insertIndex + i];
				}
				self.movies = updatedMovies;
				[self.tableView insertRowsAtIndexes:insertIndexes withAnimation:NSTableViewAnimationSlideDown];

				[self.progressSpinner stopAnimation:nil];
			});
		}
		else {
			RFDispatchMainAsync (^{
				NSUInteger movieIndex = [self.movies indexOfObjectIdenticalTo:movie];
				if (movieIndex != NSNotFound) {
					[self toggleDisclosureOpen:NO atRow:(NSInteger)movieIndex];
				}
				[self.openEpisodes removeObjectForKey:episodeKey];
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) collapseRow:(NSInteger)row
{
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	MBMovie* movie = [self.movies objectAtIndex:row];
	NSMutableArray* updatedMovies = [self.movies mutableCopy];
	NSMutableIndexSet* rowsToRemove = [NSMutableIndexSet indexSet];

	if ([movie hasSeasons]) {
		NSArray* openSeasonsForMovie = [self.openSeasons objectForKey:movie.tmdbID];
		if (openSeasonsForMovie != nil) {
			if (openSeasonsForMovie.count > 0) {
				for (MBMovie* season in openSeasonsForMovie) {
					NSString* seasonEpisodeKey = [self episodeDictionaryKeyForMovie:season];
					NSArray* openEpisodesForSeason = [self.openEpisodes objectForKey:seasonEpisodeKey];
					if (openEpisodesForSeason.count > 0) {
						for (MBMovie* episode in openEpisodesForSeason) {
							NSUInteger episodeIndex = [updatedMovies indexOfObjectIdenticalTo:episode];
							if (episodeIndex != NSNotFound) {
								[rowsToRemove addIndex:episodeIndex];
							}
						}
						[self.openEpisodes removeObjectForKey:seasonEpisodeKey];
					}

					NSUInteger seasonIndex = [updatedMovies indexOfObjectIdenticalTo:season];
					if (seasonIndex != NSNotFound) {
						[rowsToRemove addIndex:seasonIndex];
					}
				}
			}
			[self.openSeasons removeObjectForKey:movie.tmdbID];
		}
	}

	NSString* episodeKeyForMovie = [self episodeDictionaryKeyForMovie:movie];
	NSArray* openEpisodesForMovie = [self.openEpisodes objectForKey:episodeKeyForMovie];
	if (openEpisodesForMovie != nil) {
		if (openEpisodesForMovie.count > 0) {
			for (MBMovie* episode in openEpisodesForMovie) {
				NSUInteger episodeIndex = [updatedMovies indexOfObjectIdenticalTo:episode];
				if (episodeIndex != NSNotFound) {
					[rowsToRemove addIndex:episodeIndex];
				}
			}
		}
		[self.openEpisodes removeObjectForKey:episodeKeyForMovie];
	}

	if (rowsToRemove.count == 0) {
		return;
	}

	[updatedMovies removeObjectsAtIndexes:rowsToRemove];
	self.movies = updatedMovies;
	[self.tableView removeRowsAtIndexes:rowsToRemove withAnimation:NSTableViewAnimationSlideUp];
}

- (BOOL) isMovieOpen:(MBMovie *)movie
{
	if (movie == nil) {
		return NO;
	}

	if ([movie hasSeasons]) {
		if (movie.tmdbID.length == 0) {
			return NO;
		}
		return ([self.openSeasons objectForKey:movie.tmdbID] != nil);
	}

	if ([movie hasEpisodes]) {
		NSString* episodeKey = [self episodeDictionaryKeyForMovie:movie];
		if (episodeKey.length == 0) {
			return NO;
		}
		return ([self.openEpisodes objectForKey:episodeKey] != nil);
	}

	return NO;
}

- (void) toggleDisclosureOpen:(BOOL)isOpen atRow:(NSInteger)row
{
	if (row < 0 || row >= (NSInteger)self.movies.count) {
		return;
	}

	MBMovieCell* cell = (MBMovieCell *)[self.tableView rowViewAtRow:row makeIfNecessary:NO];
	if (cell) {
		[cell setDisclosureOpen:isOpen];
	}
}

#pragma mark -

- (void) fetchDiscover
{
	self.movies = @[];
	[self.openSeasons removeAllObjects];
	[self.openEpisodes removeAllObjects];
	self.tableView.animator.alphaValue = 0.0;

	RFClient* client = [[RFClient alloc] initWithPath:@"/movies/discover"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_movies = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.posterURL = [item objectForKey:@"image"];
				m.url = [item objectForKey:@"url"];
				m.title = [item objectForKey:@"title"];
				m.username = [[[[item objectForKey:@"authors"] firstObject] objectForKey:@"_microblog"] objectForKey:@"username"];

				[new_movies addObject:m];
			}
			
			RFDispatchMainAsync (^{
				self.movies = new_movies;
				[self.tableView reloadData];
				self.tableView.animator.alphaValue = 1.0;
				[self stopLoadingSidebarRow];
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) fetchMoviesWithSearch:(NSString *)search
{
	self.movies = @[];
	[self.openSeasons removeAllObjects];
	[self.openEpisodes removeAllObjects];
	self.tableView.animator.alphaValue = 0.0;

	NSDictionary* args = @{ @"q": search };

	RFClient* client = [[RFClient alloc] initWithPath:@"/movies/search"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_movies = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.posterURL = [item objectForKey:@"image"];
				m.title = [item objectForKey:@"title"];
				m.year = [[item objectForKey:@"_microblog"] objectForKey:@"year"];
				m.director = [[item objectForKey:@"_microblog"] objectForKey:@"director"];
				m.seasonsCount = [[[item objectForKey:@"_microblog"] objectForKey:@"seasons_count"] integerValue];
				m.tmdbID = [[item objectForKey:@"_microblog"] objectForKey:@"tmdb_id"];
				m.postText = [[item objectForKey:@"_microblog"] objectForKey:@"post_text"];

				[new_movies addObject:m];
			}
			
			RFDispatchMainAsync (^{
				self.movies = new_movies;
				[self.tableView reloadData];
				self.tableView.animator.alphaValue = 1.0;
				[self stopLoadingSidebarRow];
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (void) stopLoadingSidebarRow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kTimelineDidStopLoading object:self userInfo:@{}];
}

- (BOOL) currentMoviesNeedInset
{
	BOOL result = NO;
	
	for (MBMovie* m in self.movies) {
		if (m.seasonsCount > 0) {
			result = YES;
			break;
		}
	}
	
	return result;
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.movies.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBMovieCell* cell = [tableView makeViewWithIdentifier:@"MovieCell" owner:self];

	if (row < self.movies.count) {
		MBMovie* m = [self.movies objectAtIndex:row];
		cell.needsInset = [self currentMoviesNeedInset];
		[cell setupWithMovie:m];
		[cell setDisclosureOpen:[self isMovieOpen:m]];

		if (m.posterImage == nil) {
			[UUHttpSession get:m.posterURL queryArguments:nil completionHandler:^(UUHttpResponse* response) {
				if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
					NSImage* img = response.parsedResponse;
					RFDispatchMain(^{
						m.posterImage = img;
						cell.posterImageView.image = img;
					});
				}
			}];
		}

	}

	return cell;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
