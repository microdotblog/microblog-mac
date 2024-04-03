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
		self.logs = @[];
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTable];
	
	[self fetchLogs];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"LogCell" bundle:nil] forIdentifier:@"LogCell"];
}

- (void) fetchLogs
{
	RFClient* client = [[RFClient alloc] initWithPath:@"/users/logs"];
	[client getWithQueryArguments:@{} completion:^(UUHttpResponse* response) {
		if ([[response parsedResponse] isKindOfClass:[NSArray class]]) {
			NSMutableArray* new_logs = [NSMutableArray array];
			for (NSDictionary* info in [response parsedResponse]) {
				MBLog* log = [[MBLog alloc] init];
				NSString* date_s = [info objectForKey:@"date"];
				log.date = [NSDate uuDateFromRfc3339String:date_s];
				log.message = [info objectForKey:@"message"];
				[new_logs addObject:log];
			}
				
			RFDispatchMain(^{
				self.logs = new_logs;
				[self.tableView reloadData];
			});
		}
	}];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.logs.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBLogCell* cell = [tableView makeViewWithIdentifier:@"LogCell" owner:self];

	if (row < self.logs.count) {
		MBLog* log = [self.logs objectAtIndex:row];
		[cell setupWithLog:log];
	}

	return cell;
}

@end
