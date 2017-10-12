//
//  RFPreferencesController.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPreferencesController.h"

@implementation RFPreferencesController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Preferences"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupFields];
	[self setupNotifications];
}

- (void) setupFields
{
	self.websiteField.delegate = self;
	self.returnButton.alphaValue = 0.0;
}

- (void) setupNotifications
{
}

#pragma mark -

- (IBAction) returnButtonPressed:(id)sender
{
	[self hideReturnButton];
	[self checkWebsite];
}

- (void) controlTextDidChange:(NSNotification *)notification
{
	NSString* s = self.websiteField.stringValue;
	if (s.length > 0) {
		[self showReturnButton];
	}
	else {
		[self hideReturnButton];
	}
}

- (IBAction) websiteTextChanged:(id)sender
{
	[self hideReturnButton];
	[self checkWebsite];
}

- (void) showReturnButton
{
	self.returnButton.animator.alphaValue = 1.0;
}

- (void) hideReturnButton
{
	self.returnButton.animator.alphaValue = 0.0;
}

- (void) checkWebsite
{
	[self.progressSpinner startAnimation:nil];
}

@end
