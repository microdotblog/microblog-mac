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
	[self setupButtons];
}

- (void) setupView
{
	NSView* v = self.postController.view;

	NSRect r = self.window.contentView.frame;
	v.frame = r;
	
	[self.window.contentView addSubview:v];
	[self.window.contentViewController addChildViewController:self.postController];
}

- (void) setupButtons
{
	NSButton* b;
	
	b = [self.window standardWindowButton:NSWindowCloseButton];
	[b setFrameOrigin:NSMakePoint(10, -2)];

	b = [self.window standardWindowButton:NSWindowMiniaturizeButton];
	[b setFrameOrigin:NSMakePoint(30, -2)];

	b = [self.window standardWindowButton:NSWindowZoomButton];
	[b setFrameOrigin:NSMakePoint(50, -2)];
}

@end
