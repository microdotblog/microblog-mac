//
//  RFAccountPopoverBox.m
//  Snippets
//
//  Created by Manton Reece on 3/24/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import "RFAccountPopoverBox.h"

#import "RFSettings.h"
#import "RFAccount.h"
#import "RFConstants.h"
#import "RFMacros.h"
#import "NSImage+Extras.h"
#import "NSAppearance+Extras.h"

@implementation RFAccountPopoverBox

- (void) awakeFromNib
{
	self.originalLightColor = self.fillColor;
	[self updateBackground];
}

- (void) updateBackground
{
	if ([self.effectiveAppearance rf_isDarkMode]) {
		self.fillColor = NSColor.clearColor;
	}
	else {
		self.fillColor = self.originalLightColor;
	}

	self.savedFillColor = self.fillColor;
}

- (void) updateTrackingAreas
{
	if (self.customTrackingArea) {
		[self removeTrackingArea:self.customTrackingArea];
	}

	self.customTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingActiveInKeyWindow | NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
	[self addTrackingArea:self.customTrackingArea];
}

- (BOOL) hasMultipleAccounts
{
	return [RFSettings accounts].count > 1;
}

- (BOOL) mouseDownCanMoveWindow
{
	return NO;
}

- (void) mouseDown:(NSEvent *)event
{
	if ([self hasMultipleAccounts]) {
		NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Accounts"];
		[menu setAutoenablesItems:YES];

		NSArray* accounts = [RFSettings accounts];
		for (RFAccount* a in accounts) {
			NSString* s = [NSString stringWithFormat:@"@%@", a.username];
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:s action:@selector(switchAccount:) keyEquivalent:@""];

			NSImage* img = [[a cachedProfileImage] rf_roundImage];
			img.size = CGSizeMake (20, 20);
			item.image = img;
			item.representedObject = a;
			item.target = self;
			
			if ([a.username isEqualToString:[RFSettings defaultAccount].username]) {
				item.state = NSControlStateValueOn;
			}
			else {
				item.state = NSControlStateValueOff;
			}

			[menu addItem:item];
		}

		NSPoint pt = NSMakePoint (0, -7);
		[menu popUpMenuPositioningItem:nil atLocation:pt inView:self];

	}
}

- (void) switchAccount:(NSMenuItem *)item
{
	RFAccount* a = item.representedObject;
	[[NSNotificationCenter defaultCenter] postNotificationName:kSwitchAccountNotification object:self userInfo:@{ kSwitchAccountUsernameKey: a.username }];
    self.fillColor = self.savedFillColor;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	// always enable our account pop-up menu
	return YES;
}
	
- (void) mouseEntered:(NSEvent *)event
{
	if ([self hasMultipleAccounts]) {
		self.fillColor = [NSColor colorNamed:@"color_profile_hover_background"];
	}
}

- (void) mouseExited:(NSEvent *)event
{
	self.fillColor = self.savedFillColor;
}

- (void) viewDidChangeEffectiveAppearance
{
	[self updateBackground];
	[self setNeedsDisplay:YES];
}

@end
