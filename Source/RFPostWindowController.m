//
//  RFPostWindowController.m
//  Snippets
//
//  Created by Manton Reece on 8/12/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFPostWindowController.h"

#import "RFPostController.h"
#import "MBPostWindow.h"
#import "RFAccount.h"
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
	[self setupPreviewTimer];
	[self setupAutosaveTimer];

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
	
	self.window.titleVisibility = NSWindowTitleHidden;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.window];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postStartProgressNotification:) name:kPostStartProgressNotification object:self.postController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postStopProgressNotification:) name:kPostStopProgressNotification object:self.postController];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(draftDidUpdateNotification:) name:kDraftDidUpdateNotification object:self.postController];
}

- (void) setupPreviewTimer
{
	self.previewTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer* timer) {
		if ([self isFrontPostWindow]) {
			NSString* title = [self.postController currentTitle];
			NSString* markdown = [self.postController currentText];
			[[NSNotificationCenter defaultCenter] postNotificationName:kEditorWindowTextDidChangeNotification object:self userInfo:@{
				kEditorWindowTextTitleKey: title,
				kEditorWindowTextMarkdownKey: markdown
			}];
		}
	}];
}

- (void) setupAutosaveTimer
{
	self.autosaveTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer* timer) {
		NSString* s = [self.postController currentText];
		if (s.length > 0) {
			NSString* path = [RFAccount autosaveDraftFileForChannel:self.postController.channel];
			[s writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
	}];
}

- (void) clearAutosaveDraft
{
	NSString* path = [RFAccount autosaveDraftFileForChannel:self.postController.channel];
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL is_dir = NO;
	if ([fm fileExistsAtPath:path isDirectory:&is_dir]) {
		if (!is_dir) {
			[fm removeItemAtPath:path error:NULL];
		}
	}
}

- (BOOL) isFrontPostWindow
{
	BOOL is_frontmost = YES;
	
	// get windows above this window, check if any are post windows
	// return YES if no post windows are above us
	
	CGWindowID this_window_id = (CGWindowID)[self.window windowNumber];
	NSArray* windows = CFBridgingRelease (CGWindowListCopyWindowInfo (kCGWindowListOptionOnScreenAboveWindow, this_window_id));
	for (NSDictionary* info in windows) {
		NSNumber* num = [info objectForKey:(NSString *)kCGWindowNumber];
		NSWindow* win = [[NSApplication sharedApplication] windowWithWindowNumber:num.integerValue];
		if (win) {
			if ([win isKindOfClass:[MBPostWindow class]]) {
				is_frontmost = NO;
			}
		}
	}
	
	return is_frontmost;
}

- (BOOL) isNeedingSavePrompt
{
	return ![self.postController isReply] && self.window.isDocumentEdited && ([self.postController currentText].length > 0);
}

- (BOOL) windowShouldClose:(NSWindow *)sender
{
	if ([self isNeedingSavePrompt]) {
		NSAlert* alert = [[NSAlert alloc] init];
		alert.messageText = @"Save changes to blog post before closing?";
		alert.informativeText = @"Saving will store the draft on Micro.blog.";
		[alert addButtonWithTitle:@"Save"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert addButtonWithTitle:@"Don't Save"];

		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				// save (if published, will revert to draft)
				self.isSavingAndClosing = YES;
				[self.postController save:nil];
			}
			else if (returnCode == 1002) {
				// don't save
				[self.previewTimer invalidate];
				[self.autosaveTimer invalidate];
				[[NSNotificationCenter defaultCenter] postNotificationName:kPostWindowDidCloseNotification object:self];
				[self clearAutosaveDraft];
				[self close];
			}
		}];
	
		return NO;
	}
	else {
		// close because we can't save this as a draft
		[self.previewTimer invalidate];
		[self.autosaveTimer invalidate];
		[[NSNotificationCenter defaultCenter] postNotificationName:kPostWindowDidCloseNotification object:self];
		[self clearAutosaveDraft];
		[self close];
		
		return YES;
	}
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

- (void) draftDidUpdateNotification:(NSNotification *)notification
{
	if (self.isSavingAndClosing) {
		[self.previewTimer invalidate];
		[self.autosaveTimer invalidate];
		[[NSNotificationCenter defaultCenter] postNotificationName:kPostWindowDidCloseNotification object:self];
		[self clearAutosaveDraft];
		[self close];
	}
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
