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

	self.editField = [[NSTextField alloc] initWithFrame:NSZeroRect];
	self.editField.translatesAutoresizingMaskIntoConstraints = NO;
	self.editField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
	self.editField.bordered = YES;
	self.editField.bezeled = YES;
	self.editField.drawsBackground = YES;
	self.editField.focusRingType = NSFocusRingTypeDefault;
	self.editField.lineBreakMode = NSLineBreakByTruncatingTail;
	self.editField.usesSingleLineMode = YES;
	self.editField.hidden = YES;
	[self addSubview:self.editField];

	[NSLayoutConstraint activateConstraints:@[
		[self.nameField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
		[self.nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
		[self.nameField.trailingAnchor constraintLessThanOrEqualToAnchor:self.countField.leadingAnchor constant:-10],
		[self.countField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
		[self.countField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
		[self.countField.widthAnchor constraintGreaterThanOrEqualToConstant:32],
		[self.editField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
		[self.editField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-80],
		[self.editField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
		[self.editField.heightAnchor constraintEqualToConstant:24]
	]];
}

- (void) setupWithCategory:(MBCategory *)category
{
	self.nameField.hidden = NO;
	self.countField.hidden = NO;
	self.editField.hidden = YES;
	self.editField.delegate = nil;
	self.editField.target = nil;
	self.editField.action = nil;
	self.nameField.stringValue = category.name ?: @"";

	if (category.postsCount != nil) {
		self.countField.stringValue = category.postsCount.stringValue;
	}
	else {
		self.countField.stringValue = @"";
	}

	self.needsLayout = YES;
	self.needsDisplay = YES;
}

- (void) setupForEditingWithCategory:(MBCategory *)category target:(id)target action:(SEL)action delegate:(id<NSTextFieldDelegate>)delegate
{
	self.nameField.hidden = YES;
	self.countField.hidden = YES;
	self.editField.hidden = NO;
	self.editField.stringValue = category.name ?: @"";
	self.editField.delegate = delegate;
	self.editField.target = target;
	self.editField.action = action;
	self.needsLayout = YES;
	self.needsDisplay = YES;
	[self.editField setNeedsDisplay:YES];
}

- (NSView *) hitTest:(NSPoint)point
{
	if (!self.editField.hidden) {
		return [super hitTest:point];
	}

	if (NSPointInRect(point, self.bounds)) {
		return self;
	}
	else {
		return nil;
	}
}

- (void) rightMouseDown:(NSEvent *)event
{
	if (!self.editField.hidden) {
		[super rightMouseDown:event];
		return;
	}

	NSTableView* table_view = [self enclosingTableView];
	if (table_view != nil) {
		[table_view rightMouseDown:event];
	}
	else {
		[super rightMouseDown:event];
	}
}

- (void) mouseDown:(NSEvent *)event
{
	if (!self.editField.hidden) {
		[super mouseDown:event];
		return;
	}

	NSTableView* table_view = [self enclosingTableView];
	if (table_view != nil) {
		[table_view mouseDown:event];
	}
	else {
		[super mouseDown:event];
	}
}

- (NSTableView *) enclosingTableView
{
	NSView* view = self.superview;
	while (view != nil) {
		if ([view isKindOfClass:[NSTableView class]]) {
			return (NSTableView *)view;
		}
		view = view.superview;
	}

	return nil;
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];

	[self updateTextColors];
}

- (void) setEmphasized:(BOOL)emphasized
{
	[super setEmphasized:emphasized];

	[self updateTextColors];
}

- (void) updateTextColors
{
	if (self.selected && self.emphasized) {
		self.nameField.textColor = [NSColor selectedControlTextColor];
		self.countField.textColor = [NSColor selectedControlTextColor];
	}
	else {
		self.nameField.textColor = [NSColor labelColor];
		self.countField.textColor = [NSColor secondaryLabelColor];
	}
}

@end
