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
	}
	
	return self;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self setupTable];
	
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

- (void) moveLeft
{
	NSInteger row = [self.tableView selectedRow];
	[self collapseRow:row];
}

- (void) moveRight
{
	NSInteger row = [self.tableView selectedRow];
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
	[self.progressSpinner startAnimation:nil];
	
	// ...
}

- (void) expandEpisodes:(MBMovie *)movie forRow:(NSInteger)row
{
	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/movies/discover/%@/seasons/1", movie.tmdbID];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_episodes = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.posterURL = [item objectForKey:@"image"];
				m.title = [item objectForKey:@"title"];

				[new_episodes addObject:m];
			}
			
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];}

- (void) collapseRow:(NSInteger)row
{
}

#pragma mark -

- (void) fetchDiscover
{
	self.movies = @[];
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
		[cell setupWithMovie:m];

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

@end
