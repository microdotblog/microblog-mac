//
//  MBVersionsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVersionsController.h"

#import "MBNote.h"
#import "MBVersion.h"
#import "MBVersionCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "UUDate.h"

@implementation MBVersionsController

- (id) initWithNote:(MBNote *)note secretKey:(NSString *)secretKey
{
	self = [super initWithWindowNibName:@"VersionsWindow"];
	if (self) {
		self.note = note;
		self.secretKey = secretKey;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTable];
	[self fetchVersions];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"VersionCell" bundle:nil] forIdentifier:@"VersionCell"];
}

- (void) fetchVersions
{
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/%@/versions", self.note.noteID];
	[client getWithCompletion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* versions = [response.parsedResponse objectForKey:@"items"];
			NSMutableArray* new_versions = [NSMutableArray array];
 				for (NSDictionary* info in versions) {
 					MBVersion* v = [[MBVersion alloc] init];

 					v.versionID = [info objectForKey:@"id"];
 					v.text = [MBNote decryptText:[info objectForKey:@"content_text"] withKey:self.secretKey];

					NSString* date_s = [info objectForKey:@"date_published"];
					v.createdAt = [NSDate uuDateFromRfc3339String:date_s];

 					[new_versions addObject:v];
 				}

				// sort by newest first
				[new_versions sortUsingComparator:^NSComparisonResult(MBVersion* a, MBVersion* b) {
					return [b.createdAt compare:a.createdAt];
				}];
			RFDispatchMain(^{
				self.versions = new_versions;
				[self.tableView reloadData];
			});
		}
	}];
}

- (IBAction) cancel:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) restore:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.versions.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBVersionCell* cell = [tableView makeViewWithIdentifier:@"VersionCell" owner:self];

	if (row < self.versions.count) {
		MBVersion* v = [self.versions objectAtIndex:row];
		[cell setupWithVersion:v];
	}

	return cell;
}

@end
