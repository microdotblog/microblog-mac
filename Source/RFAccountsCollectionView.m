//
//  RFAccountsCollectionView.m
//  Snippets
//
//  Created by Manton Reece on 3/24/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFAccountsCollectionView.h"

#import "RFConstants.h"
#import "RFMacros.h"
#import "RFAccount.h"
#import "RFSettings.h"

@implementation RFAccountsCollectionView

- (void) mouseDown:(NSEvent *)event
{
	[super mouseDown:event];

	if (event.modifierFlags & NSEventModifierFlagControl) {
		[self showOptionsMenuForEvent:event];
	}
}

- (void) rightMouseDown:(NSEvent *)event
{
	[super rightMouseDown:event];
	
	[self showOptionsMenuForEvent:event];
}

- (void) showOptionsMenuForEvent:(NSEvent *)event
{
	RFDispatchSeconds (0.2, ^{
		NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Options"];

		NSString* s = @"Remove Account";
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:s action:@selector(removeAccount:) keyEquivalent:@""];
		[menu addItem:item];

		[NSMenu popUpContextMenu:menu withEvent:event forView:self];
	});
}

- (void) removeAccount:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kRemoveAccountNotification object:self];
}

@end
