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
	NSLog(@"Search: %@", [sender stringValue]);
	
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
		// ...
	}
}

#pragma mark -

- (void) fetchMoviesWithSearch:(NSString *)search
{
	self.movies = @[];
	self.tableView.animator.alphaValue = 0.0;

	NSDictionary* args = @{ @"q": search };

	RFClient* client = [[RFClient alloc] initWithPath:@"/posts/movies"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_movies = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBMovie* m = [[MBMovie alloc] init];
				m.title = [item objectForKey:@"title"];

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
	}

	return cell;
}

@end
