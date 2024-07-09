//
//  MBInfoController.m
//  Micro.blog
//
//  Created by Manton Reece on 7/9/24.
//  Copyright © 2024 Micro.blog. All rights reserved.
//

#import "MBInfoController.h"

#import "RFConstants.h"

@implementation MBInfoController

- (id) init
{
	self = [super initWithWindowNibName:@"Info" owner:self];
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

- (void) setupWithURL:(NSString *)url text:(NSString *)text
{
	self.url = url;
	self.text = text;
	
	if (self.window != nil) {
		[self setupFields];
	}
}

- (void) setupFields
{
	self.urlField.stringValue = self.url;
	self.textField.stringValue = [NSString stringWithFormat:@"🤖 %@", self.text];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInfoNotification:) name:kUpdateInfoNotification object:nil];
}

- (void) updateInfoNotification:(NSNotification *)notification
{
	self.url = [notification.userInfo objectForKey:kInfoURLKey];
	self.text = [notification.userInfo objectForKey:kInfoTextKey];
	
	[self setupFields];
}

- (IBAction) copyText:(id)sender
{
}

@end
