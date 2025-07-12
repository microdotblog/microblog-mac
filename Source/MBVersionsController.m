//
//  MBVersionsController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/12/25.
//  Copyright © 2025 Micro.blog. All rights reserved.
//

#import "MBVersionsController.h"

@implementation MBVersionsController

- (void) windowDidLoad
{
	[super windowDidLoad];
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
