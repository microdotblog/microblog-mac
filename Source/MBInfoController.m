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
	// replace quotes to make alt text pasting easier
	NSString* s = [text stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	
	self.url = url;
	self.text = s;
	
	if (self.window != nil) {
		[self setupFields];
	}
}

- (void) setupFields
{
	self.urlField.stringValue = self.url;
	if (self.text.length > 0) {
		self.textField.stringValue = [NSString stringWithFormat:@"🤖 %@", self.text];
		self.textCopyButton.hidden = NO;
	}
	else {
		self.textField.stringValue = @"";
		self.textCopyButton.hidden = YES;
	}
	
	[self.textCopyButton setTitle:@"Copy Text"];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInfoNotification:) name:kUpdateInfoNotification object:nil];
}

- (void) updateInfoNotification:(NSNotification *)notification
{
	NSString* url = [notification.userInfo objectForKey:kInfoURLKey];
	NSString* text = [notification.userInfo objectForKey:kInfoTextKey];
	
	[self setupWithURL:url text:text];
}

- (IBAction) copyText:(id)sender
{
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb clearContents];
	[pb setString:self.text forType:NSPasteboardTypeString];
	
	[self.textCopyButton setTitle:@"Copied"];
}

@end
