//
//  MBEditTagsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/27/23.
//  Copyright © 2023 Micro.blog. All rights reserved.
//

#import "MBEditTagsController.h"

@implementation MBEditTagsController

- (id) initWithBookmarkID:(NSString *)bookmarkID
{
	self = [super initWithWindowNibName:@"EditTags"];
	if (self) {
		self.bookmarkID = bookmarkID;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	self.tagsField.stringValue = @"hi, yes";
}

- (IBAction) cancel:(id)sender
{
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction) update:(id)sender
{
	// save tags to server
	// ...
	
	[self.progressSpinner startAnimation:nil];
	
	[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

@end
