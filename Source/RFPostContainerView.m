//
//  RFPostContainerView.m
//  Snippets
//
//  Created by Manton Reece on 10/26/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPostContainerView.h"

#import "NSAppearance+Extras.h"
#import "RFConstants.h"

@implementation RFPostContainerView

- (void) awakeFromNib
{
	[self setupBackground];
	[self setupNotifications];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(darkModeAppearanceDidChangeNotification:) name:kDarkModeAppearanceDidChangeNotification object:nil];
}

- (void) setupBackground
{
	if ([NSAppearance rf_isDarkMode]) {
		self.layer.backgroundColor = [NSColor colorNamed:@"color_post_background_darkmode"].CGColor;
	}
	else {
		self.layer.backgroundColor = [NSColor whiteColor].CGColor;
	}
}

- (void) darkModeAppearanceDidChangeNotification:(NSNotification *)notification
{
	[self setupBackground];
}

- (void) mouseDown:(NSEvent *)event
{
	// don't let clicks fall through to timeline underneath
}

@end
