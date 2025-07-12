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
#import "RFClient.h"
#import "RFMacros.h"

@implementation MBVersionsController

- (id) initWithNote:(MBNote *)note
{
	self = [super initWithWindowNibName:@"VersionsWindow"];
	if (self) {
		self.note = note;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self fetchVersions];
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
				v.text = [info objectForKey:@"content_text"];
				v.createdAt = [info objectForKey:@"date_published"];

				[new_versions addObject:v];
			}
			
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

@end
