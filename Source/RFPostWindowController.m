//
//  RFPostWindowController.m
//  Snippets
//
//  Created by Manton Reece on 8/12/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFPostWindowController.h"

#import "RFPostController.h"
#import "RFConstants.h"

@implementation RFPostWindowController

- (instancetype) initWithPostController:(RFPostController *)postController
{
	self = [super initWithWindowNibName:@"PostWindow"];
	if (self) {
		self.postController = postController;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupView];
	[self setupToolbar];
	[self setupNotifications];
	
	self.window.delegate = self;
}

- (void) setupView
{
	NSView* v = self.postController.view;

	NSRect r = self.window.contentView.frame;
	v.frame = r;
	
	[self.window.contentView addSubview:v];
	[self.window.contentViewController addChildViewController:self.postController];

	v.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
}

- (void) setupToolbar
{
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"PostToolbar"];

	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setDelegate:self];
	
	[self.window setToolbar:toolbar];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.window];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postStartProgressNotification:) name:kPostStartProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postStopProgressNotification:) name:kPostStopProgressNotification object:nil];
}

- (BOOL) windowShouldClose:(NSWindow *)sender
{
	return YES;
}

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self.postController becomeFirstResponder];
}

#pragma mark -

- (void) postStartProgressNotification:(NSNotification *)notification
{
	[self.progressSpinner startAnimation:nil];
	self.progressSpinner.hidden = NO;
}

- (void) postStopProgressNotification:(NSNotification *)notification
{
	[self.progressSpinner stopAnimation:nil];
	self.progressSpinner.hidden = YES;
}

#pragma mark -

- (NSArray<NSToolbarItemIdentifier> *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return @[ NSToolbarFlexibleSpaceItemIdentifier, @"Progress", @"SendPost" ];
}

- (NSArray<NSToolbarItemIdentifier> *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return @[ NSToolbarFlexibleSpaceItemIdentifier, @"Progress", @"SendPost" ];
}

- ( NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	if ([itemIdentifier isEqualToString:@"Progress"]) {
		NSRect r = NSMakeRect (0, 0, 30, 30);

		self.progressSpinner = [[NSProgressIndicator alloc] initWithFrame:r];
		self.progressSpinner.indeterminate = YES;
		self.progressSpinner.style = NSProgressIndicatorStyleSpinning;
		self.progressSpinner.controlSize = NSControlSizeSmall;
		self.progressSpinner.hidden = YES;
		
		NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		item.view = self.progressSpinner;
		return item;
	}
	else if ([itemIdentifier isEqualToString:@"SendPost"]) {
		NSString* title = [self.postController postButtonTitle];
		NSButton* b = [NSButton buttonWithTitle:title target:self.postController action:@selector(sendPost:)];
		NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
		item.view = b;
		return item;
	}
	else {
		return nil;
	}
}

@end
