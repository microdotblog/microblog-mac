//
//  RFPostWindowController.m
//  Snippets
//
//  Created by Manton Reece on 4/4/20.
//  Copyright © 2020 Riverfold Software. All rights reserved.
//

#import "RFPostWindowController.h"

#import "RFPostController.h"
#import "RFConstants.h"
#import "RFMacros.h"

@implementation RFPostWindowController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"PostWindow"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self showNewPost];
}

- (void) showNewPost
{
	self.postController = [[RFPostController alloc] init];

	NSRect r = self.containerView.bounds;
	self.postController.view.frame = r;
	self.postController.view.alphaValue = 0.0;
	
	self.postController.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.containerView addSubview:self.postController.view];

	self.postController.view.animator.alphaValue = 1.0;
	[self.window makeFirstResponder:self.postController.textView];
	self.postController.nextResponder = self;
	[self addResizeConstraintsToOverlay:self.postController.view containerView:self.containerView];
}

- (void) addResizeConstraintsToOverlay:(NSView *)addingView containerView:(NSView *)lastView
{
	NSLayoutConstraint* left_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0];
	left_constraint.priority = NSLayoutPriorityDefaultHigh;
	left_constraint.active = YES;

	NSLayoutConstraint* right_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0];
	right_constraint.priority = NSLayoutPriorityDefaultHigh;
	right_constraint.active = YES;

	NSLayoutConstraint* top_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
	top_constraint.priority = NSLayoutPriorityDefaultHigh;
	top_constraint.active = YES;

	NSLayoutConstraint* bottom_constraint = [NSLayoutConstraint constraintWithItem:addingView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:lastView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
	bottom_constraint.priority = NSLayoutPriorityDefaultHigh;
	bottom_constraint.active = YES;
}

@end
