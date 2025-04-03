//
//  MBLogsController.m
//  Micro.blog
//
//  Created by Manton Reece on 4/3/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBLogsController.h"

#import "MBLog.h"
#import "MBLogCell.h"
#import "RFClient.h"
#import "RFMicropub.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "UUDate.h"

@implementation MBLogsController

- (id) init
{
	self = [super initWithWindowNibName:@"Logs" owner:self];
	if (self) {
		self.allLogs = @[];
		self.errorLogs = @[];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTable];
	[self setupTimer];
	[self setupNotifications];
	
	[self fetchLogs];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"LogCell" bundle:nil] forIdentifier:@"LogCell"];
}

- (void) setupTimer
{
	[self.refreshTimer invalidate];
	self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer* timer) {
		[self fetchLogs];
	}];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
}

- (void) refresh
{
	[self setupTimer];
	[self fetchLogs];
}

- (void) fetchLogs
{
	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/users/logs"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([[response parsedResponse] isKindOfClass:[NSArray class]]) {
			NSMutableArray* new_logs = [NSMutableArray array];
			NSMutableArray* new_errors = [NSMutableArray array];
			for (NSDictionary* info in [response parsedResponse]) {
				MBLog* log = [[MBLog alloc] init];
				NSString* date_s = [info objectForKey:@"date"];
				log.date = [NSDate uuDateFromRfc3339String:date_s];
				log.message = [info objectForKey:@"message"];
				[new_logs addObject:log];
				if ([[info objectForKey:@"is_error"] boolValue]) {
					[new_errors addObject:log];
				}
			}
			
			RFDispatchMain(^{
				self.allLogs = new_logs;
				self.errorLogs = new_errors;

				if ([self checkNeedingReload]) {
					[self reloadRestoringSelection];
				}

				[self fetchErrors];
			});
		}
	}];
}

- (void) fetchErrors
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/users/logs/errors"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([[response parsedResponse] isKindOfClass:[NSArray class]]) {
			NSMutableArray* new_errors = [NSMutableArray array];
			for (NSDictionary* info in [response parsedResponse]) {
				MBLog* log = [[MBLog alloc] init];
				NSString* date_s = [info objectForKey:@"date"];
				log.date = [NSDate uuDateFromRfc3339String:date_s];
				log.message = [info objectForKey:@"message"];
				[new_errors addObject:log];
			}
				
			RFDispatchMain(^{
				self.errorLogs = new_errors;
				
				if ([self checkNeedingReload]) {
					[self reloadRestoringSelection];
				}
				
				[self.progressSpinner stopAnimation:nil];
			});
		}
	}];
}

- (BOOL) checkNeedingReload
{
	MBLog* new_latest = [self.allLogs firstObject];

	if (self.latestDate != nil) {
		if (new_latest && [new_latest.date isEqualTo:self.latestDate]) {
			return NO;
		}
	}
	
	if (new_latest) {
		self.latestDate = new_latest.date;
	}
	
	return YES;
}

- (void) reloadRestoringSelection
{
	NSIndexSet* index_set = [self.tableView selectedRowIndexes];
	[self.tableView reloadData];
	[self.tableView selectRowIndexes:index_set byExtendingSelection:NO];
}

- (IBAction) segmentChanged:(NSSegmentedControl *)sender
{
	self.isShowingErrors = (sender.selectedSegment == 1);
	[self.tableView reloadData];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.refreshTimer invalidate];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	if (self.isShowingErrors) {
		return self.errorLogs.count;
	}
	else {
		return self.allLogs.count;
	}
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBLogCell* cell = [tableView makeViewWithIdentifier:@"LogCell" owner:self];

	if (self.isShowingErrors) {
		if (row < self.errorLogs.count) {
			MBLog* log = [self.errorLogs objectAtIndex:row];
			[cell setupWithLog:log];
		}
	}
	else {
		if (row < self.allLogs.count) {
			MBLog* log = [self.allLogs objectAtIndex:row];
			[cell setupWithLog:log];
		}
	}

	return cell;
}

@end
