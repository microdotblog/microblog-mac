//
//  RFPostWindowController.m
//  Snippets
//
//  Created by Manton Reece on 8/12/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFPostWindowController.h"

#import "RFPostController.h"

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

@end
