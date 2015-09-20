//
//  AppDelegate.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/20/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	[self setupTextView];
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
}

- (void) setupTextView
{
	self.textView.font = [NSFont systemFontOfSize:15 weight:NSFontWeightLight];
	self.textView.backgroundColor = [NSColor colorWithCalibratedWhite:0.973 alpha:1.000];
}

@end
