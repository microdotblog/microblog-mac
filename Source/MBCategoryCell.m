//
//  MBCategoryCell.m
//  Micro.blog
//
//  Created by Manton Reece on 6/4/26.
//  Copyright © 2026 Micro.blog. All rights reserved.
//

#import "MBCategoryCell.h"

#import "MBCategory.h"

@implementation MBCategoryCell

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self setupViews];
	}

	return self;
}

- (void) setupViews
{
	self.identifier = @"CategoryCell";

	self.nameField = [NSTextField labelWithString:@""];
	self.nameField.translatesAutoresizingMaskIntoConstraints = NO;
	self.nameField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
	self.nameField.lineBreakMode = NSLineBreakByTruncatingTail;
	[self addSubview:self.nameField];

	self.countField = [NSTextField labelWithString:@""];
	self.countField.translatesAutoresizingMaskIntoConstraints = NO;
	self.countField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
	self.countField.textColor = [NSColor secondaryLabelColor];
	self.countField.alignment = NSTextAlignmentRight;
	self.countField.lineBreakMode = NSLineBreakByTruncatingTail;
	[self addSubview:self.countField];

	[NSLayoutConstraint activateConstraints:@[
		[self.nameField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
		[self.nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
		[self.nameField.trailingAnchor constraintLessThanOrEqualToAnchor:self.countField.leadingAnchor constant:-10],
		[self.countField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
		[self.countField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
		[self.countField.widthAnchor constraintGreaterThanOrEqualToConstant:32]
	]];
}

- (void) setupWithCategory:(MBCategory *)category
{
	self.nameField.stringValue = category.name ?: @"";

	if (category.postsCount != nil) {
		self.countField.stringValue = category.postsCount.stringValue;
	}
	else {
		self.countField.stringValue = @"";
	}
}

- (void) setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
	[super setBackgroundStyle:backgroundStyle];

	if (backgroundStyle == NSBackgroundStyleEmphasized) {
		self.nameField.textColor = [NSColor selectedControlTextColor];
		self.countField.textColor = [NSColor selectedControlTextColor];
	}
	else {
		self.nameField.textColor = [NSColor labelColor];
		self.countField.textColor = [NSColor secondaryLabelColor];
	}
}

@end
