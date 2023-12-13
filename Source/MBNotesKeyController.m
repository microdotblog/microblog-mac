//
//  MBNotesKeyController.m
//  Micro.blog
//
//  Created by Manton Reece on 12/11/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBNotesKeyController.h"

#import "RFConstants.h"
#import "SAMKeychain.h"

@implementation MBNotesKeyController

- (id) init
{
	self = [super initWithWindowNibName:@"NotesKeyWindow"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
}

- (IBAction) cancel:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) unlockNotes:(id)sender
{
	NSString* s = self.secretKeyField.stringValue;
	if ([s containsString:@"mkey"]) {
		[SAMKeychain setPassword:s forService:@"Micro.blog Notes" account:@""];
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotesKeyUpdatedNotification object:self];
	}
	
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

@end
