//
//  MBBookCell.m
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBookCell.h"

#import "MBBook.h"
#import "RFBookshelf.h"
#import "MBNote.h"
#import "RFConstants.h"

@implementation MBBookCell

- (void) awakeFromNib
{
	[super awakeFromNib];

	self.coverImageView.wantsLayer = YES;
	self.coverImageView.layer.cornerRadius = 4;
	self.coverImageView.layer.masksToBounds = YES;
}

- (void) setupWithBook:(MBBook *)book inBookshelf:(RFBookshelf *)bookshelf
{
	self.book = book;
	self.bookshelf = bookshelf;
	
	self.titleField.stringValue = book.title;
	
	if ([book.authors count] > 0) {
		self.authorField.stringValue = [book.authors firstObject];
	}
	else {
		self.authorField.stringValue = @"";
	}
	
	self.coverImageView.image = book.coverImage;
	if (book.coverImage == nil) {
		self.coverImageView.image = [book cachedCover];
	}
	
	[self updateButtonVisibility];
}

- (void) drawBackgroundInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	[self.backgroundColor set];
	NSRectFill (r);
}

- (void) drawSelectionInRect:(NSRect)dirtyRect
{
	CGRect r = self.bounds;
	if ([self.superview isKindOfClass:[NSTableView class]]) {
		NSTableView* table = (NSTableView *)self.superview;
		if (![table.window isKeyWindow]) {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
		else if (table.window.firstResponder == table) {
			[[NSColor selectedContentBackgroundColor] set];
		}
		else {
			[[NSColor colorNamed:@"color_row_unfocused_selection"] set];
		}
	}
	
	NSRectFill (r);
}

- (void) setSelected:(BOOL)selected
{
	[super setSelected:selected];
	
	[self updateButtonVisibility];
}

- (void) updateButtonVisibility
{
	// Search results show the add button in place of the options button.
	self.addButton.hidden = (self.book.bookID != nil);
	self.optionsButton.hidden = !self.selected || self.book.bookID == nil;
	self.addNoteButton.hidden = !self.selected || ![MBNote hasSecretKey];
}

- (IBAction) addBook:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kAddBookNotification object:self userInfo:@{
		kAddBookKey: self.book,
		kAddBookBookshelfKey: self.bookshelf
	}];	
}

- (IBAction) showOptionsMenu:(id)sender
{
	NSView* view = self.superview;
	while (view && ![view isKindOfClass:[NSTableView class]]) {
		view = view.superview;
	}
	NSTableView* table = (NSTableView *)view;
	if (!table) {
		return;
	}

	NSInteger row = [table rowForView:self];
	if (row < 0) {
		return;
	}
	[table.window makeFirstResponder:table];
	[table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	NSMenu* menu = table.menu;
	NSButton* button = self.optionsButton;
	NSPoint point = NSMakePoint(NSMinX(button.bounds), button.isFlipped ? NSMaxY(button.bounds) : NSMinY(button.bounds));
	[menu popUpMenuPositioningItem:nil atLocation:point inView:button];
}

- (IBAction) addNote:(id)sender
{
	if (![MBNote hasSecretKey]) {
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kAddNoteNotification object:self userInfo:@{
		kAddNoteBookKey: self.book,
		kAddNoteBookshelfKey: self.bookshelf
	}];
}

@end
