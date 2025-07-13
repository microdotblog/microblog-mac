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
#import "RFConstants.h"
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
	
	self.restoreButton.enabled = NO;

	[self setupTable];
	[self fetchVersions];
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"VersionCell" bundle:nil] forIdentifier:@"VersionCell"];
}

- (void) fetchVersions
{
	[self.progressSpinner startAnimation:nil];
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/notes/%@/versions", self.note.noteID];
	[client getWithCompletion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSArray* versions = [response.parsedResponse objectForKey:@"items"];
			NSMutableArray* new_versions = [NSMutableArray array];
 				for (NSDictionary* info in versions) {
 					MBVersion* v = [[MBVersion alloc] init];

 					v.versionID = [info objectForKey:@"id"];
					NSString* s = [info objectForKey:@"content_text"];
					if ([MBNote isProbablyEncrypted:s]) {
						s = [MBNote decryptText:s withKey:self.secretKey];
					}
					v.text = s;

					NSString* date_s = [info objectForKey:@"date_published"];
					v.createdAt = [NSDate uuDateFromRfc3339String:date_s];

					// only use the version if there's text in it
					if (v.text.length > 0) {
						[new_versions addObject:v];
					}
 				}

				// sort by newest first
				[new_versions sortUsingComparator:^NSComparisonResult(MBVersion* a, MBVersion* b) {
					return [b.createdAt compare:a.createdAt];
				}];
			RFDispatchMain(^{
				self.versions = new_versions;
				[self.tableView reloadData];
				[self.progressSpinner stopAnimation:nil];
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
	[self.progressSpinner startAnimation:nil];

	NSInteger row = self.tableView.selectedRow;
	MBVersion* v = [self.versions objectAtIndex:row];

	RFClient* client = [[RFClient alloc] initWithPath:@"/notes"];
	NSString* s = v.text;
	
	if (self.note.isEncrypted) {
		s = [MBNote encryptText:s withKey:self.secretKey];
	}
	
	NSDictionary* args = @{
		@"id": self.note.noteID,
		@"text": s,
		@"is_encrypted": [NSNumber numberWithBool:self.note.isEncrypted],
		@"notebook_id": self.note.notebookID
	};
		
	[client postWithParams:args completion:^(UUHttpResponse* response) {
		RFDispatchMainAsync(^{
			[self.progressSpinner stopAnimation:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshNotesNotification object:self];
			[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
		});
	}];
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

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		self.restoreButton.enabled = YES;
	}
	else {
		self.restoreButton.enabled = NO;
	}
}

@end
